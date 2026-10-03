import MechanicsModel
import MechanicsJoints

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

    internal init(descriptor: MechanicalDescriptor, policy: CompilationPolicy, tree: KinematicTree, initialSnapshot: KinematicSnapshot,
                  report: CompilationReport, sparsity: StructuralSparsity, manifest: FeatureManifest,
                  validatorRegistrations: [ValidatorRegistration], cacheDependencies: [CacheDependency], extensionEvidence: [ExtensionValidationEvidence]) {
        self.descriptor = descriptor; self.policy = policy; self.stamp = ModelStamp(identity: descriptor.identity, revision: descriptor.revision)
        self.tree = tree; self.initialSnapshot = initialSnapshot; self.report = report; self.sparsity = sparsity; self.manifest = manifest
        self.validatorRegistrations = validatorRegistrations; self.cacheDependencies = cacheDependencies; self.extensionEvidence = extensionEvidence
    }

    public func validating(stamp: ModelStamp) throws(CompilationFailure) {
        guard stamp.identity == self.stamp.identity else { throw .one(.wrongModel, .coordinates, message: "State belongs to another model.") }
        guard stamp.revision == self.stamp.revision else { throw .one(.staleRevision, .coordinates, message: "State revision does not match this compiled model.") }
    }

    public func makeState(_ state: KinematicState) throws(CompilationFailure) -> CompiledKinematicState {
        guard state.revision == stamp.revision else { throw .one(.staleRevision, .coordinates, message: "State revision does not match this compiled model.") }
        do { _ = try TreeKinematicsEvaluator().evaluate(tree, state: state, policy: policy.jointPolicy) }
        catch { throw .one(.invalidCoordinates, .coordinates, message: "State failed actual compiled-tree chart/frame validation.") }
        return CompiledKinematicState(stamp: stamp, state: state)
    }

    public func evaluate(_ state: CompiledKinematicState) throws(CompilationFailure) -> KinematicSnapshot {
        try validating(stamp: state.stamp)
        do { return try TreeKinematicsEvaluator().evaluate(tree, state: state.state, policy: policy.jointPolicy) }
        catch { throw .one(.invalidCoordinates, .coordinates, message: "State failed actual compiled-tree evaluation.") }
    }
}
