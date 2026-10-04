import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifyRuntimeReplacement() throws {
        let source = try MechanicalProbeModel(), target = try replacementProbeModel(source)
        let provider = try ProbeRuntimeContributors()
        let capacity = try RuntimeCapacity(maximumPhysicalScalars: 19, maximumContributors: 1, maximumContributorBytes: 8,
            maximumMetadataBytes: 1000, maximumCheckpointBytes: 4096, maximumValidationWork: 8, maximumValidationScratchBytes: 0,
            maximumObservationLeases: 1, maximumBatchStates: 1, maximumTransactions: 10, maximumStepWorkUnits: 8, maximumWorkBetweenSafePoints: 2)
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "replacement-swift-6.4.0", backend: "reference-cpu", precision: "float64"),
            requiredContributors: provider.schemas, capacity: capacity, determinism: .sameBuildReplay, workload: "before-replacement")
        let handler = ReferenceRuntimeCheckpointHandler(contributors: provider, revisions: ReferenceModelRevisionUpdater())
        let session = try RuntimeSession(model: source.model, configuration: configuration, initialState: source.descriptor.initialState,
            contributors: [ProbeRuntimeContributors.record(0)], seed: 42, checkpoints: handler)
        defer { _ = session.shutdown() }
        let prefix = session.snapshot()
        let nextConfiguration = try RuntimeConfiguration(continuation: configuration.continuation, requiredContributors: [], capacity: capacity,
            determinism: .sameBuildReplay, workload: "after-replacement")
        let nextHandler = ReferenceRuntimeCheckpointHandler(contributors: NoRuntimeContributors(), revisions: ReferenceModelRevisionUpdater())
        let request = RuntimeModelReplacement(expectedSource: prefix.checkpoint, model: target, physical: target.descriptor.initialState,
            contributors: [], configuration: nextConfiguration, checkpoints: nextHandler)
        let operation: any RuntimeModelReplacing = session
        let changed = try operation.replaceModel(request)
        try require(changed.physical.state.q.count == 7 && changed.physical.state.v.count == 6)
        try require(changed.checkpoint.random == prefix.checkpoint.random && changed.checkpoint.acceptedSteps == 1)
        try require(session.configuration == nextConfiguration && session.profile().reservedPhysicalScalars == 19)
        var staleRejected = false
        do throws(RuntimeFailure) { _ = try operation.replaceModel(request) }
        catch { try require(error.code == .incompatibleModel && error.lastAccepted == changed); staleRejected = true }
        try require(staleRejected && session.snapshot() == changed && prefix.physical.state.q.count == 1)
        let advanced = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 1); try trial.setPosition(2, at: 2); try trial.setVelocity(3, at: 5)
            _ = try trial.nextRandom(); try trial.setTime(0.25); return .accept
        }
        try require(advanced.accepted.checkpoint.random.draws == 1 && advanced.accepted.checkpoint.acceptedSteps == 2)
        try require(advanced.accepted.physical.state.q[2] == 2 && advanced.accepted.physical.state.v[5] == 3 && advanced.accepted.checkpoint.contributors.isEmpty)
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        let bytes = try session.checkpoint(codec: codec)
        let restored = try session.restart(bytes, codec: codec)
        try require(restored == advanced.accepted)
    }
    @inline(never)
    private static func replacementProbeModel(_ source: MechanicalProbeModel) throws -> CompiledMechanicalModel {
        let original = source.descriptor.joints[0].record
        let joint = try JointRecord(id: EntityID(kind: .joint, key: "replacement-six-dof"), parentBody: original.parentBody, childBody: original.childBody,
            parentAnchor: original.parentAnchor, childAnchor: original.childAnchor, manifold: JointManifold(.sixDOF))
        let physical = try KinematicState(revision: 2, time: 0, q: [0,0,0,1,0,0,0], v: [0,0,0,0,0,2], acceleration: [0,0,0,0,0,0])
        let descriptor = try MechanicalDescriptor(identity: source.descriptor.identity, revision: 2, bodies: source.descriptor.bodies,
            joints: [MechanicalJoint(record: joint, authority: .dynamicState)], root: source.descriptor.root, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: source.descriptor.worldFrame, initialState: physical, representationRequirements: [], features: [], extensions: [])
        let old = source.policy
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 6, maximumJacobianScalars: 72),
            jointPolicy: old.jointPolicy, inertiaPolicy: old.inertiaPolicy, translationTolerance: old.translationTolerance, rotationTolerance: old.rotationTolerance,
            maximumRecords: old.maximumRecords, maximumIdentifierBytes: old.maximumIdentifierBytes, maximumSparsityEntries: 72,
            maximumDependencyEntries: old.maximumDependencyEntries, maximumExtensionRecords: old.maximumExtensionRecords,
            maximumDiagnostics: old.maximumDiagnostics, extensionBudget: old.extensionBudget, target: compilerVerificationTarget)
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
    }
}
