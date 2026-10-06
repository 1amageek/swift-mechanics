public struct BoundedSDFCodec<Compiler: MechanicalModelCompiling>: SDFDocumentCoding, Sendable {
    public let compiler: Compiler
    public init(compiler: Compiler) { self.compiler = compiler }

    public func decode(bytes: [UInt8], options: SDFImportOptions, compilationPolicy: CompilationPolicy,
                       work: inout SDFWork) throws(SDFError) -> SDFScene {
        do {
            try work.charge(1)
            for text in [options.identity, options.source.source, options.worldFrame.key] {
                try work.inspect(text)
                guard text.utf8.count <= work.policy.maximumTokenBytes else { throw SDFError.invalidInput(node: 0) }
            }
            if let root = options.assetRoot {
                try work.inspect(root.key)
                guard root.key.utf8.count <= work.policy.maximumTokenBytes,
                      root.allowedSchemes.count <= work.policy.maximumNamedRecords,
                      root.allowedPathPrefixes.count <= work.policy.maximumNamedRecords else { throw SDFError.invalidInput(node: 0) }
                for text in root.allowedSchemes {
                    try work.inspect(text)
                    guard text.utf8.count <= work.policy.maximumAssetBytes else { throw SDFError.invalidInput(node: 0) }
                }
                for text in root.allowedPathPrefixes {
                    try work.inspect(text)
                    guard text.utf8.count <= work.policy.maximumAssetBytes else { throw SDFError.invalidInput(node: 0) }
                }
            }
            let document = try work.decodeXML(bytes)
            let nodes = try SDFNodes(document, work: &work)
            var admission = SDFAdmission(nodes: nodes, options: options, compilation: compilationPolicy)
            try admission.collect(work: &work)
            var projection = SDFModelProjection(admission: admission)
            var assemblies: [SDFAssembly] = [], tops: [String] = []
            try work.comparisons(admission.declarations.count)
            for declaration in admission.declarations where declaration.kind == .model && declaration.scope.isEmpty {
                try work.row()
                let descriptor = try projection.descriptor(declaration.name, work: &work)
                // The injected compiler owns actual topology/inertia/pose admission and its separate capacities.
                let model = try compiler.compile(descriptor, policy: compilationPolicy)
                try work.charge(1)
                assemblies.append(SDFAssembly(scopedName: declaration.name, model: model,
                    gravity: try AffineGravity(frame: options.worldFrame, accelerationAtOrigin: admission.gravity)))
                tops.append(declaration.name)
            }
            var frames: [SDFResolvedFrame] = []
            frames.reserveCapacity(admission.declarations.count + 1)
            frames.append(SDFResolvedFrame(scopedName: "world", originalNode: document.rootIndex,
                initialWorldPose: .identity, attachedBody: nil, assemblyIndex: nil, placementInAttachedBody: .identity))
            for index in admission.declarations.indices {
                try work.row(); try work.charge(160 + tops.count * work.policy.maximumTokenBytes)
                let declaration = admission.declarations[index], owner = admission.attachments[index]
                let body: EntityID?, assembly: Int?, local: RigidTransform
                if owner < 0 {
                    body = nil; assembly = nil; local = admission.poses[index]
                } else {
                    let ownerDeclaration = admission.declarations[owner]
                    guard ownerDeclaration.kind == .link,
                          let target = tops.firstIndex(of: ownerDeclaration.top) else { throw SDFError.invalidTopology(declaration.name) }
                    body = try projection.bodyID(ownerDeclaration.name); assembly = target
                    local = try admission.poses[owner].inverted().composed(with: admission.poses[index])
                }
                frames.append(SDFResolvedFrame(scopedName: declaration.name, originalNode: declaration.node,
                    initialWorldPose: admission.poses[index], attachedBody: body, assemblyIndex: assembly, placementInAttachedBody: local))
            }
            try work.charge(1)
            return SDFScene(source: options.source, worldFrame: options.worldFrame, worldName: admission.worldName,
                assemblies: assemblies, frames: frames, assets: projection.admission.assets,
                losses: projection.admission.losses, originalDocument: document)
        } catch let failure as SDFError { throw failure }
          catch let failure as CoreError { throw .core(failure) }
          catch let failure as ModelError { throw .model(failure) }
          catch let failure as JointError { throw .joint(failure) }
          catch let failure as LoadError { throw .load(failure) }
          catch let failure as CompilationFailure { throw .compilation(failure) }
          catch let failure as NumericalError { throw .numerical(failure) }
          catch { throw .unexpectedSupplier }
    }

    /// Exports the original admitted snapshot, preserving XML normalization and all explicit loss records.
    public func encode(_ scene: SDFScene, expectedSource: SourceProvenance,
                       work: inout SDFWork) throws(SDFError) -> [UInt8] {
        try work.inspect(expectedSource.source); try work.inspect(scene.source.source)
        guard scene.source == expectedSource else { throw .staleSource }
        for assembly in scene.assemblies {
            try work.charge(2)
            guard assembly.model.stamp.revision == scene.source.revision else { throw .staleSource }
        }
        return try work.encodeXML(scene.originalDocument)
    }

    public func frameMotion(_ scopedName: String, in scene: SDFScene, expectedSource: SourceProvenance,
                            states: [KinematicState], work: inout SDFWork) throws(SDFError) -> FrameMotion {
        do {
            try work.inspect(expectedSource.source); try work.inspect(scene.source.source); try work.inspect(scopedName)
            guard scene.source == expectedSource, states.count == scene.assemblies.count else { throw SDFError.staleSource }
            for index in states.indices {
                try work.charge(2)
                guard states[index].revision == scene.assemblies[index].model.stamp.revision else { throw SDFError.staleSource }
            }
            var selected: SDFResolvedFrame?
            for frame in scene.frames {
                try work.inspect(frame.scopedName)
                if frame.scopedName == scopedName { selected = frame; break }
            }
            guard let frame = selected else { throw SDFError.unknownFrame(scopedName) }
            guard let index = frame.assemblyIndex, let body = frame.attachedBody else {
                try work.charge(1); return .stationary(pose: frame.initialWorldPose)
            }
            let assembly = scene.assemblies[index], state = states[index]
            guard state.revision == assembly.model.stamp.revision else { throw SDFError.staleSource }
            let scalars = try NumericalWork.product(assembly.model.tree.bodies.count,
                NumericalWork.sum(64, NumericalWork.product(assembly.model.tree.layout.velocityCount, 24)))
            try work.reserve(scalars)
            try work.charge(try NumericalWork.product(scalars, 32))
            let snapshot = try TreeKinematicsEvaluator().evaluate(assembly.model.tree, state: state, policy: assembly.model.policy.jointPolicy)
            let original = try snapshot.body(body).motion
            let motion = try FrameMotionComposer().composed(parent: original, relative: .stationary(pose: frame.placementInAttachedBody))
            try work.charge(1)
            return motion
        } catch let failure as SDFError { throw failure }
          catch let failure as CoreError { throw .core(failure) }
          catch let failure as JointError { throw .joint(failure) }
          catch let failure as NumericalError { throw .numerical(failure) }
          catch { throw .unexpectedSupplier }
    }

    public func initialGravityLoads(in scene: SDFScene, expectedSource: SourceProvenance,
                                    work: inout LoadWork) throws(SDFError) -> [GravityResponse] {
        do {
            guard !Task.isCancelled else { throw LoadError.cancelled }
            guard scene.source == expectedSource else { throw SDFError.staleSource }
            var count = 0
            for assembly in scene.assemblies { count = try LoadWork.sum(count, assembly.model.descriptor.bodies.count) }
            try work.reserve(scalars: LoadWork.product(count, 32))
            var result: [GravityResponse] = []; result.reserveCapacity(count)
            for assembly in scene.assemblies {
                for body in assembly.model.descriptor.bodies {
                    guard !Task.isCancelled else { throw LoadError.cancelled }
                    try work.charge(64)
                    guard case .spatial(let original) = body, let inertia = original.inertia else {
                        throw SDFError.missing(element: "explicit mass for gravity operation", node: 0)
                    }
                    let motion = try assembly.model.initialSnapshot.body(original.id).motion
                    let center = try motion.pose.transforming(point: inertia.properties.centerOfMass)
                    let sample = try GravitySample(point: center, mass: inertia.properties.mass)
                    result.append(try GravityEvaluator().point(assembly.gravity, body: original.id, sample: sample, work: &work))
                }
            }
            guard !Task.isCancelled else { throw LoadError.cancelled }
            return result
        } catch let failure as SDFError { throw failure }
          catch let failure as CoreError { throw .core(failure) }
          catch let failure as JointError { throw .joint(failure) }
          catch let failure as LoadError { throw .load(failure) }
          catch { throw .unexpectedSupplier }
    }
}
