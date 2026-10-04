
public struct ReferenceMechanicalCompiler<Extensions: MechanicalExtensionValidating>: MechanicalModelCompiling, Sendable {
    public let extensions: Extensions
    public init(extensions: Extensions) { self.extensions = extensions }

    public func compile(_ source: MechanicalDescriptor, policy: CompilationPolicy) throws(CompilationFailure) -> CompiledMechanicalModel {
        try cancelled()
        let suppliedRegistrations = extensions.registrations
        try inputBounds(source, registrations: suppliedRegistrations, policy: policy)
        let registrations = suppliedRegistrations.sorted { before($0.schema, $1.schema) }
        let descriptor = try canonical(source)
        let registered = try registrationMap(registrations)
        let identities = try validateIdentitiesAndTopology(descriptor)
        var bodies: [KinematicBody] = []
        bodies.reserveCapacity(descriptor.bodies.count)
        for body in descriptor.bodies {
            do { bodies.append(try body.kinematicBody()) }
            catch { throw .one(.producerValidationFailure, .input, records: [body.id], message: "Body geometry projection failed.") }
        }
        let tree: KinematicTree
        do {
            tree = try KinematicTree(bodies: bodies, joints: descriptor.joints.map { $0.record }, root: descriptor.root,
                rootBase: descriptor.rootBase, worldFrame: descriptor.worldFrame, revision: descriptor.revision, capacity: policy.kinematicCapacity)
        } catch {
            throw .one(.producerValidationFailure, .topology, records: descriptor.joints.map { $0.record.id }, message: "Producer rejected tree geometry/layout/capacity.")
        }
        try validateBodies(descriptor, tree: tree, policy: policy)
        try validateCoordinates(descriptor, tree: tree, policy: policy)
        let snapshot: KinematicSnapshot
        do { snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: descriptor.initialState, policy: policy.jointPolicy) }
        catch { throw .one(.invalidCoordinates, .coordinates, records: descriptor.joints.map { $0.record.id }, message: "Initial state failed actual tree/anchor derivative evaluation.") }
        try validatePoses(descriptor, snapshot: snapshot, policy: policy)
        try validateRepresentations(descriptor)
        let manifest = try capabilityManifest(descriptor, registrations: registrations, policy: policy)
        let context = ExtensionValidationContext(descriptor: descriptor, tree: tree)
        var work = NumericalWork(budget: policy.extensionBudget)
        var extensionEvidence: [ExtensionValidationEvidence] = []
        extensionEvidence.reserveCapacity(descriptor.extensions.count)
        for record in descriptor.extensions {
            try cancelled()
            guard let registration = registered[record.schema] else {
                throw .one(.unknownSchema, .extensionValidation, records: [record.id], message: "No validated schema owner is registered.")
            }
            let budget: NumericalBudget
            do { budget = try work.remainingBudget(reservedStorage: 0) }
            catch { throw .one(.validatorBudgetExceeded, .extensionValidation, records: [record.id], message: "Extension budget exhausted.") }
            let evidence: ExtensionValidationEvidence
            do { evidence = try extensions.validate(record, context: context, budget: budget) }
            catch { throw bounded(error, policy: policy, record: record.id) }
            guard evidence.feature == registration.feature, evidence.work.budget == budget,
                  evidence.dependencies.count <= policy.maximumDependencyEntries,
                  evidence.dependencies.allSatisfy({ dependency in
                      guard let entity = dependency.entity else { return true }
                      return identities.contains(entity)
                  }) else {
                throw .one(.invalidValidatorEvidence, .extensionValidation, records: [record.id], message: "Validator returned mismatched feature/budget or unknown dependencies.")
            }
            do { try work.absorb(evidence.work, reservedStorage: 0) }
            catch { throw .one(.validatorBudgetExceeded, .extensionValidation, records: [record.id], message: "Cumulative extension work exceeded policy.") }
            extensionEvidence.append(evidence)
        }
        try cancelled()
        let compiled = try buildStructure(descriptor, tree: tree, extensionEvidence: extensionEvidence, policy: policy)
        let ambient = try product(tree.bodies.count, tree.bodies[0].dimension == .planar ? 3 : 6)
        guard ambient >= tree.layout.velocityCount else { throw .one(.producerValidationFailure, .layout, message: "Admitted local subspace exceeds tree ambient dimension.") }
        let rank = StructuralTreeRank(rank: ambient - tree.layout.velocityCount, ambientBodyVelocityCount: ambient,
            generalizedVelocityCount: tree.layout.velocityCount, dimension: tree.bodies[0].dimension, configurationTime: descriptor.initialState.time)
        let report = CompilationReport(bodyCount: tree.bodies.count, frameCount: tree.frameCount, jointCount: tree.joints.count,
            extensionCount: descriptor.extensions.count, positionCount: tree.layout.positionCount, velocityCount: tree.layout.velocityCount, structuralTreeRank: rank)
        return CompiledMechanicalModel(admission: _MechanicalCompilationAdmission(descriptor: descriptor, policy: policy, tree: tree, initialSnapshot: snapshot, report: report,
            sparsity: compiled.0, manifest: manifest, validatorRegistrations: registrations, cacheDependencies: compiled.1, extensionEvidence: extensionEvidence))
    }

    private func cancelled() throws(CompilationFailure) {
        guard !Task.isCancelled else { throw .one(.cancelled, .input, message: "Compilation cancelled before publication.") }
    }
    // String ordering shares canonical-equivalence semantics with EntityID equality/hashing.
    private func before(_ left: String, _ right: String) -> Bool { left < right }
    private func identityKindOrder(_ kind: EntityKind) -> Int {
        switch kind {
        case .body: 0
        case .frame: 1
        case .joint: 2
        case .collider: 3
        case .material: 4
        case .load: 5
        case .actuator: 6
        case .sensor: 7
        }
    }
    private func canonical(_ source: MechanicalDescriptor) throws(CompilationFailure) -> MechanicalDescriptor {
        try MechanicalDescriptor(identity: source.identity, revision: source.revision,
            bodies: source.bodies.sorted { before($0.id.key, $1.id.key) },
            joints: source.joints.sorted { before($0.record.id.key, $1.record.id.key) }, root: source.root,
            rootBase: source.rootBase, rootAuthority: source.rootAuthority, worldFrame: source.worldFrame, initialState: source.initialState,
            representationRequirements: source.representationRequirements.sorted { before($0.body.key, $1.body.key) },
            features: source.features.sorted { before($0.feature, $1.feature) },
            extensions: source.extensions.sorted {
                if $0.id.key != $1.id.key { return before($0.id.key, $1.id.key) }
                return identityKindOrder($0.id.kind) < identityKindOrder($1.id.kind)
            })
    }
    private func sum(_ left: Int, _ right: Int) throws(CompilationFailure) -> Int {
        do { return try NumericalWork.sum(left, right) }
        catch { throw .one(.integerOverflow, .layout, message: "Compiler count addition overflowed.") }
    }
    private func product(_ left: Int, _ right: Int) throws(CompilationFailure) -> Int {
        do { return try NumericalWork.product(left, right) }
        catch { throw .one(.integerOverflow, .layout, message: "Compiler count multiplication overflowed.") }
    }
    private func inputBounds(_ source: MechanicalDescriptor, registrations: [ValidatorRegistration], policy: CompilationPolicy) throws(CompilationFailure) {
        let anchors = try product(source.joints.count, 2)
        let frames = try sum(try sum(source.bodies.count, 1), anchors)
        let records = try sum(try sum(source.bodies.count, frames), try sum(source.joints.count, source.extensions.count))
        guard records <= policy.maximumRecords, registrations.count <= policy.maximumRecords,
              source.representationRequirements.count <= policy.maximumRecords, source.features.count <= policy.maximumRecords,
              source.initialState.prescribedAnchors.count <= policy.maximumRecords,
              source.extensions.count <= policy.maximumExtensionRecords else {
            throw .one(.capacityExceeded, .input, message: "Descriptor/registration record count exceeds compiler policy.")
        }
        var bytes = 0
        func charge(_ string: String) throws(CompilationFailure) {
            bytes = try sum(bytes, string.utf8.count)
            guard bytes <= policy.maximumIdentifierBytes else { throw .one(.capacityExceeded, .input, message: "Identifier/metadata UTF-8 bytes exceed compiler policy.") }
        }
        try charge(source.identity); try charge(source.root.key); try charge(source.worldFrame.key)
        for body in source.bodies {
            try charge(body.id.key); try charge(body.frame.key)
            for representation in [body.representations.geometricShape, body.representations.displayGeometry, body.representations.collisionGeometry] {
                if let representation { try charge(representation.assetKey); try charge(representation.provenance.source) }
            }
            switch body {
            case .planar(let record): if let inertia = record.inertia { try charge(inertia.provenance.source) }
            case .spatial(let record): if let inertia = record.inertia { try charge(inertia.provenance.source) }
            }
        }
        for joint in source.joints { try charge(joint.record.id.key); try charge(joint.record.parentBody.key); try charge(joint.record.childBody.key); try charge(joint.record.parentAnchor.frame.key); try charge(joint.record.childAnchor.frame.key) }
        for feature in source.features { try charge(feature.feature) }
        for requirement in source.representationRequirements { try charge(requirement.body.key) }
        for sample in source.initialState.prescribedAnchors { try charge(sample.frame.key) }
        for record in source.extensions {
            try charge(record.id.key); try charge(record.schema)
            guard record.parameters.count <= policy.maximumRecords, record.references.count <= policy.maximumRecords else {
                throw .one(.capacityExceeded, .input, records: [record.id], message: "Extension parameter/reference count exceeds policy.")
            }
            for parameter in record.parameters { try charge(parameter.name) }
            for reference in record.references { try charge(reference.key) }
        }
        for registration in registrations { try charge(registration.schema); try charge(registration.feature); try charge(registration.owner); try charge(registration.evidenceRevision) }
    }
    private func registrationMap(_ registrations: [ValidatorRegistration]) throws(CompilationFailure) -> [String: ValidatorRegistration] {
        var result: [String: ValidatorRegistration] = [:], features: Set<String> = []
        for registration in registrations {
            guard registration.operation == .descriptorValidation else { throw .one(.unsupportedCapability, .capabilities, message: "This compiler accepts descriptor validators, not declared execution providers.") }
            guard registration.feature != "mechanics.compiler.tree", result[registration.schema] == nil,
                  features.insert(registration.feature).inserted else { throw .one(.duplicateRegistration, .capabilities, message: "Schemas and feature owners must be unique.") }
            result[registration.schema] = registration
        }
        return result
    }
    private func validateIdentitiesAndTopology(_ descriptor: MechanicalDescriptor) throws(CompilationFailure) -> Set<EntityID> {
        guard descriptor.root.kind == .body, descriptor.worldFrame.kind == .frame, !descriptor.bodies.isEmpty else {
            throw .one(.invalidRoot, .topology, records: [descriptor.root], message: "Tree requires a body root and world frame.")
        }
        var identities: Set<EntityID> = [descriptor.worldFrame], indices: [EntityID: Int] = [:]
        func insert(_ id: EntityID) throws(CompilationFailure) {
            guard identities.insert(id).inserted else { throw .one(.duplicateIdentity, .identities, records: [id], message: "Entity identity has multiple definitions.") }
        }
        for (index, body) in descriptor.bodies.enumerated() { try cancelled(); try insert(body.id); try insert(body.frame); indices[body.id] = index }
        guard let root = indices[descriptor.root] else { throw .one(.invalidRoot, .topology, records: [descriptor.root], message: "Root body is not defined.") }
        var children = [[Int]](repeating: [], count: descriptor.bodies.count), incoming = [Int](repeating: 0, count: descriptor.bodies.count)
        for joint in descriptor.joints {
            let record = joint.record
            try insert(record.id); try insert(record.parentAnchor.frame); try insert(record.childAnchor.frame)
            guard let parent = indices[record.parentBody], let child = indices[record.childBody] else {
                throw .one(.danglingReference, .topology, records: [record.id, record.parentBody, record.childBody], message: "Joint endpoint is not a defined body.")
            }
            incoming[child] += 1
            guard incoming[child] == 1 else { throw .one(.multipleParents, .topology, records: [record.id, record.childBody], message: "Tree child has multiple incoming joints.") }
            children[parent].append(child)
        }
        for record in descriptor.extensions { try insert(record.id) }
        for record in descriptor.extensions {
            for reference in record.references {
                guard identities.contains(reference) else { throw .one(.danglingReference, .extensionValidation, records: [record.id, reference], message: "Extension reference is undefined.") }
            }
        }
        var degrees = incoming, queue = incoming.indices.filter { incoming[$0] == 0 }, cursor = 0
        while cursor < queue.count {
            let parent = queue[cursor]; cursor += 1
            for child in children[parent] { degrees[child] -= 1; if degrees[child] == 0 { queue.append(child) } }
        }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Cyclic mechanical descriptors reach this compiler branch.
        // Loop assembly/rank is not implemented; a loop provider and actual assembly proof are required before success.
        guard queue.count == descriptor.bodies.count else { throw .one(.unsupportedClosedLoop, .topology, records: descriptor.joints.map { $0.record.id }, message: "Cyclic topology requires the unimplemented loop-assembly integration domain.") }
        guard incoming[root] == 0 else { throw .one(.invalidRoot, .topology, records: [descriptor.root], message: "Root has an incoming joint.") }
        for index in descriptor.bodies.indices where index != root {
            guard incoming[index] == 1 else { throw .one(.disconnectedTree, .topology, records: [descriptor.bodies[index].id], message: "Tree body is not connected to the root.") }
        }
        return identities
    }
    private func validateBodies(_ descriptor: MechanicalDescriptor, tree: KinematicTree, policy: CompilationPolicy) throws(CompilationFailure) {
        guard (descriptor.rootBase == .fixed) == (descriptor.rootAuthority == .fixed) else {
            throw .one(.incompatibleCoordinateAuthority, .modes, records: [descriptor.root], message: "Fixed and free base charts require matching authority.")
        }
        let bodyMap = Dictionary(uniqueKeysWithValues: descriptor.bodies.map { ($0.id, $0) })
        let jointMap = Dictionary(uniqueKeysWithValues: descriptor.joints.map { ($0.record.id, $0) })
        var dynamicPath: [EntityID: Bool] = [:], prescribedPath: [EntityID: Bool] = [:]
        dynamicPath[descriptor.root] = descriptor.rootAuthority == .dynamicState
        prescribedPath[descriptor.root] = descriptor.rootAuthority == .prescribedMotion
        for joint in tree.joints {
            guard let wrapper = jointMap[joint.id], let parentDynamic = dynamicPath[joint.parentBody], let parentPrescribed = prescribedPath[joint.parentBody] else {
                throw .one(.producerValidationFailure, .modes, records: [joint.id], message: "Canonical tree authority dependency is missing.")
            }
            guard (joint.manifold.velocityCount == 0) == (wrapper.authority == .fixed) else {
                throw .one(.incompatibleCoordinateAuthority, .modes, records: [joint.id], message: "Fixed and free joint charts require matching authority.")
            }
            var prescribedAnchor = false
            for anchor in [joint.parentAnchor, joint.childAnchor] { if case .prescribed = anchor.placement { prescribedAnchor = true } }
            dynamicPath[joint.childBody] = parentDynamic || wrapper.authority == .dynamicState
            prescribedPath[joint.childBody] = parentPrescribed || wrapper.authority == .prescribedMotion || prescribedAnchor
        }
        for treeBody in tree.bodies {
            try cancelled()
            guard let body = bodyMap[treeBody.id], let dynamic = dynamicPath[treeBody.id], let prescribed = prescribedPath[treeBody.id] else {
                throw .one(.producerValidationFailure, .modes, records: [treeBody.id], message: "Body authority path is undefined.")
            }
            if body.mode == .static && (dynamic || prescribed) {
                throw .one(.incompatibleBodyMode, .modes, records: [body.id], message: "Static body has a structurally moving coordinate/anchor ancestor.")
            }
            if body.mode == .prescribedKinematic && (dynamic || !prescribed) {
                throw .one(.incompatibleBodyMode, .modes, records: [body.id], message: "Kinematic body requires fully prescribed motion and no dynamic-state ancestor.")
            }
            switch body {
            case .planar(let record):
                if record.mode == .dynamic && record.inertia == nil { throw .one(.invalidInertia, .inertia, records: [body.id], message: "Dynamic body inertia is required.") }
                if let inertia = record.inertia {
                    do { _ = try MassProperties2D(mass: inertia.properties.mass, centerX: inertia.properties.centerX, centerY: inertia.properties.centerY, polarInertiaAtCenter: inertia.properties.polarInertiaAtCenter) }
                    catch { throw .one(.invalidInertia, .inertia, records: [body.id], message: "Planar inertia failed physical validation.") }
                }
            case .spatial(let record):
                if record.mode == .dynamic && record.inertia == nil { throw .one(.invalidInertia, .inertia, records: [body.id], message: "Dynamic body inertia is required.") }
                if let inertia = record.inertia {
                    do { _ = try MassProperties3D(mass: inertia.properties.mass, centerOfMass: inertia.properties.centerOfMass, inertiaAtCenter: inertia.properties.inertiaAtCenter, policy: policy.inertiaPolicy, origin: inertia.properties.origin) }
                    catch { throw .one(.invalidInertia, .inertia, records: [body.id], message: "Spatial inertia failed requested physicality policy.") }
                }
            }
        }
    }
    private func validateCoordinates(_ descriptor: MechanicalDescriptor, tree: KinematicTree, policy: CompilationPolicy) throws(CompilationFailure) {
        let state = descriptor.initialState
        guard state.revision == descriptor.revision else { throw .one(.staleRevision, .coordinates, message: "Initial state revision is stale.") }
        guard state.q.count == tree.layout.positionCount, state.v.count == tree.layout.velocityCount, state.acceleration.count == tree.layout.velocityCount else {
            throw .one(.invalidCoordinates, .coordinates, message: "Initial q/v/acceleration counts disagree with canonical layout.")
        }
        let evaluator = JointMotionEvaluator()
        for (index, joint) in tree.joints.enumerated() {
            let layout = tree.layout.joints[index]
            do { _ = try evaluator.evaluate(joint.manifold, q: state.q[layout.positions.range], v: state.v[layout.velocities.range], acceleration: state.acceleration[layout.velocities.range], policy: policy.jointPolicy) }
            catch { throw .one(.invalidCoordinates, .coordinates, records: [joint.id], message: "Joint initial chart/rate/acceleration failed actual motion validation.") }
        }
    }
    private func validatePoses(_ descriptor: MechanicalDescriptor, snapshot: KinematicSnapshot, policy: CompilationPolicy) throws(CompilationFailure) {
        for body in descriptor.bodies {
            let reference: RigidTransform, actual: RigidTransform
            do { reference = try body.kinematicBody().referencePose; actual = try snapshot.body(body.id).motion.pose }
            catch { throw .one(.producerValidationFailure, .initialAssembly, records: [body.id], message: "Body initial pose query failed.") }
            do {
                let error = try actual.translation.subtracting(reference.translation).magnitude()
                let scale = try reference.translation.magnitude()
                let angle = try actual.rotation.multiplied(by: reference.rotation.conjugated()).rotationVector().magnitude()
                guard try policy.translationTolerance.contains(error: error, scale: scale),
                      try policy.rotationTolerance.contains(error: angle, scale: 1) else {
                    throw CompilationFailure.one(.inconsistentInitialPose, .initialAssembly, records: [body.id], message: "Stored body pose disagrees with actual initial tree configuration.")
                }
            } catch {
                throw .one(.inconsistentInitialPose, .initialAssembly, records: [body.id], message: "Body initial translation/rotation violates requested geometric tolerance.")
            }
        }
    }
    private func validateRepresentations(_ descriptor: MechanicalDescriptor) throws(CompilationFailure) {
        let bodyMap = Dictionary(uniqueKeysWithValues: descriptor.bodies.map { ($0.id, $0) })
        var seen: Set<EntityID> = []
        for requirement in descriptor.representationRequirements {
            guard seen.insert(requirement.body).inserted else { throw .one(.invalidInput, .representations, records: [requirement.body], message: "Duplicate representation requirement.") }
            guard let body = bodyMap[requirement.body] else { throw .one(.danglingReference, .representations, records: [requirement.body], message: "Representation body is undefined.") }
            for kind in requirement.geometry {
                do { _ = try body.representations.requiring(kind) }
                catch { throw .one(.missingRepresentation, .representations, records: [body.id], message: "Required physical/visual representation is absent.") }
            }
            if requirement.inertia != .none {
                let quality: InertialQuality?
                switch body { case .planar(let record): quality = record.inertia?.quality; case .spatial(let record): quality = record.inertia?.quality }
                guard let quality else { throw .one(.missingRepresentation, .representations, records: [body.id], message: "Required inertial representation is absent.") }
                if requirement.inertia == .exactRequired && quality != .exact {
                    throw .one(.approximationForbidden, .representations, records: [body.id], message: "Exact inertia required; bounded approximation was supplied.")
                }
            }
        }
    }
    private func capabilityManifest(_ descriptor: MechanicalDescriptor, registrations: [ValidatorRegistration], policy: CompilationPolicy) throws(CompilationFailure) -> FeatureManifest {
        let domain: MechanicalDomain = descriptor.bodies[0].dimension == .planar ? .planarTree : .spatialTree
        let admitted = Set(["mechanics.compiler.tree"] + registrations.map { $0.feature })
        for feature in descriptor.features {
            // FIXME(INCOMPLETE_IMPLEMENTATION): Execution feature requests reach this admission branch.
            // Dynamics/contact/loop/integration providers and target behavior proofs are required before execution admission.
            guard feature.operation == .descriptorValidation, admitted.contains(feature.feature), feature.domain == domain,
                  feature.precision == .float64, feature.backend == .referenceCPU, feature.target == policy.target else {
                throw .one(.unsupportedCapability, .capabilities, message: "Requested feature/model/backend/precision/target execution combination is not implemented by this compiler.")
            }
        }
        let builtin: FeatureRequirement
        do { builtin = try FeatureRequirement(feature: "mechanics.compiler.tree", operation: .descriptorValidation, domain: domain, precision: .float64, backend: .referenceCPU, target: policy.target) }
        catch { throw .one(.producerValidationFailure, .capabilities, message: "Compiler capability record construction failed.") }
        var entries = [FeatureManifestEntry(requirement: builtin, owner: "MechanicsCompiler", evidenceRevision: "local-model-" + String(descriptor.revision), qualification: .descriptorValidated(modelRevision: descriptor.revision))]
        for registration in registrations where descriptor.extensions.contains(where: { $0.schema == registration.schema }) {
            let requirement = try FeatureRequirement(feature: registration.feature, operation: .descriptorValidation, domain: domain,
                precision: .float64, backend: .referenceCPU, target: policy.target)
            entries.append(FeatureManifestEntry(requirement: requirement, owner: registration.owner, evidenceRevision: registration.evidenceRevision, qualification: .descriptorValidated(modelRevision: descriptor.revision)))
        }
        let execution = try FeatureRequirement(feature: "mechanics.kinematics.tree", operation: .treeKinematics, domain: domain,
            precision: .float64, backend: .referenceCPU, target: policy.target)
        entries.append(FeatureManifestEntry(requirement: execution, owner: "MechanicsJoints", evidenceRevision: "f291f24",
            qualification: .executionUnqualified(reason: "Compiler composition/execution target qualification is owned by root exact-profile integration.")))
        return FeatureManifest(entries: entries, producerEvidence: [ProducerPathEvidence(owner: "MechanicsJoints", revision: "f291f24",
            scope: "Native local joint/tree suites; separately exercised WASI/Embedded spherical rate and fixed-root hinge/point/power/stale-state paths only.")])
    }
    private func bounded(_ failure: CompilationFailure, policy: CompilationPolicy, record: EntityID) -> CompilationFailure {
        guard failure.diagnostics.count <= policy.maximumDiagnostics,
              failure.diagnostics.allSatisfy({ $0.message.utf8.count <= policy.maximumIdentifierBytes && $0.records.count <= policy.maximumRecords }) else {
            return .one(.validatorBudgetExceeded, .extensionValidation, records: [record], message: "Validator diagnostic output exceeded policy.")
        }
        return failure
    }
    private func buildStructure(_ descriptor: MechanicalDescriptor, tree: KinematicTree,
                                extensionEvidence: [ExtensionValidationEvidence], policy: CompilationPolicy) throws(CompilationFailure) -> (StructuralSparsity, [CacheDependency]) {
        let rows = try product(tree.bodies.count, 6), offsetsCount = try sum(rows, 1)
        var rowOffsets: [Int] = [0], columnIndices: [Int] = [], caches: [CacheDependency] = []
        rowOffsets.reserveCapacity(offsetsCount)
        var columns: [EntityID: [Int]] = [:], ancestorJoints: [EntityID: [EntityID]] = [:]
        columns[descriptor.root] = Array(0..<tree.rootBase.velocityCount); ancestorJoints[descriptor.root] = []
        var dependencyEntries = 0
        func cache(_ key: CompiledCacheKey, _ inputs: [ParameterReference]) throws(CompilationFailure) {
            dependencyEntries = try sum(dependencyEntries, inputs.count)
            guard dependencyEntries <= policy.maximumDependencyEntries, caches.count < policy.maximumRecords else {
                throw .one(.capacityExceeded, .layout, message: "Compiled dependency/cache records exceed policy.")
            }
            caches.append(CacheDependency(cache: key, inputs: inputs))
        }
        for (index, joint) in tree.joints.enumerated() {
            guard let parentColumns = columns[joint.parentBody], let ancestors = ancestorJoints[joint.parentBody] else {
                throw .one(.producerValidationFailure, .layout, records: [joint.id], message: "Tree dependency order is invalid.")
            }
            guard ancestors.count < policy.maximumDependencyEntries else { throw .one(.capacityExceeded, .layout, message: "Ancestor dependency depth exceeds policy.") }
            columns[joint.childBody] = parentColumns + Array(tree.layout.joints[index].velocities.range)
            ancestorJoints[joint.childBody] = ancestors + [joint.id]
        }
        for body in tree.bodies {
            try cancelled()
            guard let bodyColumns = columns[body.id], let ancestors = ancestorJoints[body.id] else { throw .one(.producerValidationFailure, .layout, records: [body.id], message: "Body dependencies missing.") }
            for _ in 0..<6 {
                let next = try sum(columnIndices.count, bodyColumns.count)
                guard next <= policy.maximumSparsityEntries else { throw .one(.capacityExceeded, .layout, records: [body.id], message: "Structural Jacobian pattern exceeds policy.") }
                columnIndices.append(contentsOf: bodyColumns); rowOffsets.append(next)
            }
            var motionInputs = [ParameterReference(entity: descriptor.root, aspect: .rootPlacement), ParameterReference(entity: nil, aspect: .initialConfiguration),
                                ParameterReference(entity: nil, aspect: .coordinateAuthority), ParameterReference(entity: nil, aspect: .topology)]
            for ancestor in ancestors {
                motionInputs.append(ParameterReference(entity: ancestor, aspect: .jointManifold)); motionInputs.append(ParameterReference(entity: ancestor, aspect: .jointAnchors))
                motionInputs.append(ParameterReference(entity: ancestor, aspect: .coordinateAuthority))
            }
            try cache(CompiledCacheKey(kind: .bodyKinematics, entity: body.id), motionInputs)
            for (kind, aspect) in [(CompiledCacheKind.bodyInertia, ParameterAspect.inertia), (.geometricRepresentation, .geometricShape), (.displayRepresentation, .displayGeometry), (.collisionRepresentation, .collisionGeometry)] {
                try cache(CompiledCacheKey(kind: kind, entity: body.id), [ParameterReference(entity: body.id, aspect: aspect)])
            }
        }
        try cache(CompiledCacheKey(kind: .stateLayout, entity: nil), [ParameterReference(entity: nil, aspect: .topology)])
        try cache(CompiledCacheKey(kind: .sparsity, entity: nil), [ParameterReference(entity: nil, aspect: .topology)])
        var admission = [ParameterReference(entity: nil, aspect: .featureRequirements), ParameterReference(entity: nil, aspect: .coordinateAuthority)]
        for body in tree.bodies { admission.append(ParameterReference(entity: body.id, aspect: .bodyMode)); admission.append(ParameterReference(entity: body.id, aspect: .bodyPlacement)) }
        for joint in tree.joints { admission.append(ParameterReference(entity: joint.id, aspect: .coordinateAuthority)) }
        try cache(CompiledCacheKey(kind: .capabilityAdmission, entity: nil), admission)
        for (index, record) in descriptor.extensions.enumerated() {
            try cache(CompiledCacheKey(kind: .extensionValidation, entity: record.id),
                [ParameterReference(entity: record.id, aspect: .extensionParameters)] + extensionEvidence[index].dependencies)
        }
        return (StructuralSparsity(rowCount: rows, columnCount: tree.layout.velocityCount, rowOffsets: rowOffsets, columnIndices: columnIndices), caches)
    }
}

// Carries complete output only after this file's actual compiler admission pipeline succeeds.
internal struct _MechanicalCompilationAdmission: Sendable {
    let descriptor: MechanicalDescriptor
    let policy: CompilationPolicy
    let tree: KinematicTree
    let initialSnapshot: KinematicSnapshot
    let report: CompilationReport
    let sparsity: StructuralSparsity
    let manifest: FeatureManifest
    let validatorRegistrations: [ValidatorRegistration]
    let cacheDependencies: [CacheDependency]
    let extensionEvidence: [ExtensionValidationEvidence]

    fileprivate init(descriptor: MechanicalDescriptor, policy: CompilationPolicy, tree: KinematicTree,
                     initialSnapshot: KinematicSnapshot, report: CompilationReport, sparsity: StructuralSparsity,
                     manifest: FeatureManifest, validatorRegistrations: [ValidatorRegistration],
                     cacheDependencies: [CacheDependency], extensionEvidence: [ExtensionValidationEvidence]) {
        self.descriptor = descriptor; self.policy = policy; self.tree = tree; self.initialSnapshot = initialSnapshot
        self.report = report; self.sparsity = sparsity; self.manifest = manifest
        self.validatorRegistrations = validatorRegistrations; self.cacheDependencies = cacheDependencies
        self.extensionEvidence = extensionEvidence
    }
}
