
public struct CompiledMechanicalModel: Sendable {
    public let descriptor: MechanicalDescriptor
    public let policy: CompilationPolicy
    public let stamp: ModelStamp
    public let tree: KinematicTree
    public let initialSnapshot: KinematicSnapshot
    public let report: CompilationReport
    public let sparsity: StructuralSparsity
    public let manifest: FeatureManifest
    public let validatorRegistrations: [ValidatorRegistration]
    public let cacheDependencies: [CacheDependency]
    public let extensionEvidence: [ExtensionValidationEvidence]

    internal init(admission: _MechanicalCompilationAdmission) {
        descriptor = admission.descriptor; policy = admission.policy
        stamp = ModelStamp(identity: admission.descriptor.identity, revision: admission.descriptor.revision)
        tree = admission.tree; initialSnapshot = admission.initialSnapshot; report = admission.report
        sparsity = admission.sparsity; manifest = admission.manifest
        validatorRegistrations = admission.validatorRegistrations
        cacheDependencies = admission.cacheDependencies; extensionEvidence = admission.extensionEvidence
    }

    public func validating(stamp: ModelStamp) throws(CompilationFailure) {
        guard stamp.identity == self.stamp.identity else { throw .one(.wrongModel, .coordinates, message: "State belongs to another model.") }
        guard stamp.revision == self.stamp.revision else { throw .one(.staleRevision, .coordinates, message: "State revision does not match this compiled model.") }
    }

    public func makeState(_ state: KinematicState) throws(CompilationFailure) -> CompiledKinematicState {
        guard state.revision == stamp.revision else { throw .one(.staleRevision, .coordinates, message: "State revision does not match this compiled model.") }
        do { _ = try TreeKinematicsEvaluator().evaluate(tree, state: state, policy: policy.jointPolicy) }
        catch { throw .one(.invalidCoordinates, .coordinates, message: "State failed actual compiled-tree chart/frame validation.") }
        return CompiledKinematicState(admission: _CompiledStateAdmission(stamp: stamp, state: state))
    }

    public func evaluate(_ state: CompiledKinematicState) throws(CompilationFailure) -> KinematicSnapshot {
        try validating(stamp: state.stamp)
        do { return try TreeKinematicsEvaluator().evaluate(tree, state: state.state, policy: policy.jointPolicy) }
        catch { throw .one(.invalidCoordinates, .coordinates, message: "State failed actual compiled-tree evaluation.") }
    }
}

// State publication authority belongs to makeState's actual compiled-tree validation.
internal struct _CompiledStateAdmission: Sendable {
    let stamp: ModelStamp
    let state: KinematicState
    fileprivate init(stamp: ModelStamp, state: KinematicState) {
        self.stamp = stamp; self.state = state
    }
}
