public struct BoundedURDFCodec<Markup: XMLDocumentCoding, Compiler: MechanicalModelCompiling>: URDFDocumentCoding {
    public let markup: Markup
    public let compiler: Compiler
    public init(markup: Markup, compiler: Compiler) { self.markup = markup; self.compiler = compiler }

    public func decode(bytes: [UInt8], options: URDFImportOptions, compilationPolicy: CompilationPolicy,
                       work: inout URDFWork) throws(URDFFailure) -> URDFImportResult {
        do {
            try work.charge(1)
            let document = try markup.decode(bytes: bytes, work: &work.xml)
            let nodes = try URDFNodes(document, work: &work)
            var admission = URDFAdmission(nodes: nodes, options: options, compilationPolicy: compilationPolicy)
            let draft = try admission.read(work: &work)
            try work.charge(1)
            let model = try compiler.compile(draft.descriptor, policy: compilationPolicy)
            try work.charge(1)
            guard model.stamp == ModelStamp(identity: options.identity, revision: options.provenance.revision) else {
                throw URDFFailure(.invalid("compiler result stamp"))
            }
            var hasCompleteInertia = true
            for body in model.descriptor.bodies {
                try work.charge(1)
                if case .spatial(let record) = body { if record.inertia == nil { hasCompleteInertia = false } }
                else { throw URDFFailure(.invalid("compiler result dimension")) }
            }
            let availability: URDFImportResult.DynamicsAvailability = model.tree.layout.velocityCount == 0
                ? .zeroVelocitiesUnsupported : (hasCompleteInertia ? .available : .missingSuppliedInertia)
            return URDFImportResult(robotName: draft.robotName, model: model, geometries: draft.geometries,
                collisions: draft.collisions, assets: draft.assets, losses: draft.losses, document: document,
                dynamicsAvailability: availability)
        } catch let error as URDFFailure { throw error }
        catch let error as XMLFailure { throw URDFFailure(.xml(error), at: error.location) }
        catch let error as CompilationFailure { throw URDFFailure(.compilation(error)) }
        catch let error as CoreError { throw URDFFailure(.core(error)) }
        catch let error as ModelError { throw URDFFailure(.model(error)) }
        catch let error as JointError { throw URDFFailure(.joint(error)) }
        catch let error as CollisionError { throw URDFFailure(.collision(error)) }
        catch { throw URDFFailure(.unexpectedProducer) }
    }

    public func encode(result: URDFImportResult, work: inout URDFWork) throws(URDFFailure) -> [UInt8] {
        do {
            let document = try URDFCanonicalWriter().document(result.document, work: &work)
            return try markup.encode(document: document, work: &work.xml)
        } catch let error as URDFFailure { throw error }
        catch let error as XMLFailure { throw URDFFailure(.xml(error), at: error.location) }
        catch { throw URDFFailure(.unexpectedProducer) }
    }
}
