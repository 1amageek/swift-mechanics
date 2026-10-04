import SwiftMechanics
import Synchronization

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyRuntime() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertia = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 1e-12)
        let input = try compilerDescriptor(inertiaPolicy: inertia, displacedChild: false)
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: inertia, translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 20,
            maximumIdentifierBytes: 2000, maximumSparsityEntries: 12, maximumDependencyEntries: 200,
            maximumExtensionRecords: 1, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: compilerVerificationTarget)
        let model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(input, policy: policy)
        let capacity = try RuntimeCapacity(maximumPhysicalScalars: 3, maximumContributors: 1, maximumContributorBytes: 8,
            maximumMetadataBytes: 1000, maximumCheckpointBytes: 4096, maximumValidationWork: 8,
            maximumValidationScratchBytes: 0, maximumObservationLeases: 1, maximumBatchStates: 2,
            maximumTransactions: 100, maximumStepWorkUnits: 8, maximumWorkBetweenSafePoints: 2)
        let provider = try ProbeRuntimeContributors()
        let config = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "probe-swift-6.4.0", backend: "reference-cpu", precision: "float64"),
            requiredContributors: provider.schemas, capacity: capacity, determinism: .sameBuildReplay, workload: "checkpoint-counter-rng")
        let handler = ReferenceRuntimeCheckpointHandler(contributors: provider, revisions: ReferenceModelRevisionUpdater())
        typealias Session = RuntimeSession<ReferenceRuntimeCheckpointHandler<ProbeRuntimeContributors, ReferenceModelRevisionUpdater>>
        let lifecycle = RuntimeProbeLifecycle()
        let first = try Session(model: model, configuration: config, initialState: input.initialState,
            contributors: [ProbeRuntimeContributors.record(0)], seed: 42, checkpoints: handler, onRelease: { lifecycle.release() })
        lifecycle.retain(first)
        let second = try Session(model: model, configuration: config, initialState: input.initialState,
            contributors: [ProbeRuntimeContributors.record(0)], seed: 42, checkpoints: handler)
        _ = try advanceRuntime(first)
        let prefix = first.snapshot()
        _ = try first.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 2); _ = try trial.nextRandom()
            try trial.setPosition(99, at: 0); try trial.replaceContributor(ProbeRuntimeContributors.record(99)); return .reject
        }
        try require(first.snapshot() == prefix && second.snapshot().checkpoint.acceptedSteps == 0)
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        let bytes = try first.checkpoint(codec: codec)
        try require(try codec.decode(bytes, capacity: capacity) == prefix.checkpoint)
        _ = try second.restart(bytes, codec: codec)
        _ = try advanceRuntime(first); _ = try advanceRuntime(second)
        try require(first.snapshot() == second.snapshot())
        try require(try first.checkpoint(codec: codec) == second.checkpoint(codec: codec))
        var corrupt = bytes; corrupt[corrupt.count-1] ^= 1
        let preserved = first.snapshot()
        var corruptRejected = false
        do throws(RuntimeFailure) { _ = try first.restart(corrupt, codec: codec) }
        catch { try require(error.code == .corruptCheckpoint && error.lastAccepted == preserved); corruptRejected = true }
        try require(corruptRejected && first.snapshot() == preserved)
        let profile = first.profile()
        try require(profile.attemptedTransactions == 4 && profile.committedTransactions == 2 && profile.rejectedTransactions == 1 && profile.failedTransactions == 1)
        try first.observe { (accepted: RuntimeAcceptedState) throws(RuntimeFailure) in
            guard accepted == preserved else { throw RuntimeFailure(.invalidState, message: "Probe observation changed accepted state.") }
            var busyRejected = false
            do throws(RuntimeFailure) { _ = try advanceRuntime(first) }
            catch { guard error.code == .busy else { throw error }; busyRejected = true }
            guard busyRejected, first.shutdown() == .draining, lifecycle.releaseCount == 0 else {
                throw RuntimeFailure(.invalidOwnerAccess, message: "Probe observation lifetime was violated.")
            }
        }
        try require(first.shutdownStatus() == .closed && lifecycle.releaseCount == 1)
        try require(first.shutdown() == .closed && lifecycle.releaseCount == 1 && first.snapshot() == preserved)
        _ = second.shutdown()
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func advanceRuntime(_ session: any RuntimeSessionOperating) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 1)
            let count = try ProbeRuntimeContributors.count(trial.contributor("probe-counter"))
            guard count < UInt64.max else { throw RuntimeFailure(.capacityExceeded, message: "Probe counter overflow.") }
            let random = try trial.nextRandom()
            try trial.setPosition(trial.position(at: 0) + Double((random & 15) + 1) / 16, at: 0)
            try trial.setVelocity(Double(count + 1), at: 0); try trial.setTime(trial.timeSeconds + 0.25)
            try trial.replaceContributor(ProbeRuntimeContributors.record(count+1)); return .accept
        }
    }
}
