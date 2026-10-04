import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class PlanarRuntimeProbeContext: Sendable {
    typealias Handler = PlanarRuntimeCheckpointHandler<ReferenceModelRevisionUpdater>
    typealias Session = RuntimeSession<Handler>
    let model: CompiledMechanicalModel
    let initial: PlanarState
    let policy: PlanarPolicy
    let codec: FixedPlanarContinuationCodec
    let operation: ReferencePlanarTrialOperator
    let session: Session

    @inline(never)
    init() throws {
        let original = try MechanicalProbeModel(), source = original.descriptor
        guard let root = source.bodies.first(where: { $0.id == source.root }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let descriptor = try MechanicalDescriptor(identity: "planar-public-carrier", revision: 1,
            bodies: [root], joints: [], root: source.root, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: source.worldFrame,
            initialState: KinematicState(revision: 1, time: 0, q: [], v: [], acceleration: []),
            representationRequirements: [], features: [], extensions: [])
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: original.policy)
        let grid = try PlanarGrid(id: "planar-public-grid", revision: 1, frame: source.worldFrame,
            source: SourceProvenance(source: "planar-public-vortex", revision: 1), nx: 6, ny: 6,
            lengthX: 2*PlanarProbeContext.pi, lengthY: 2*PlanarProbeContext.pi, depth: 0.5, density: 1, viscosity: 0.1,
            limits: PlanarLimits(maximumCells: 64, maximumMetadataBytes: 1024, maximumSpeed: 10,
                maximumPressure: 10000, maximumAcceleration: 10, maximumStep: 1))
        initial = try PlanarProbeContext.vortex(grid)
        policy = try PlanarProbeContext.policy()
        codec = try FixedPlanarContinuationCodec(grid: grid, model: model.stamp, contributorID: "planar-fluid",
            maximumBytes: 8192, divergenceTolerance: 1e-9)
        operation = ReferencePlanarTrialOperator(codec: codec, flow: PlanarProbeContext.solver())
        var bytes = try Self.byteWork()
        let record = try codec.encode(initial, work: &bytes)
        let capacity = try RuntimeCapacity(maximumPhysicalScalars: 0, maximumContributors: 1,
            maximumContributorBytes: 8192, maximumMetadataBytes: 2048, maximumCheckpointBytes: 16384,
            maximumValidationWork: 100000, maximumValidationScratchBytes: 30000,
            maximumObservationLeases: 1, maximumBatchStates: 1, maximumTransactions: 16,
            maximumStepWorkUnits: 4, maximumWorkBetweenSafePoints: 1)
        let configuration = try RuntimeConfiguration(
            continuation: RuntimeContinuationIdentity(build: "planar-swift-6.4.0", backend: "reference-cpu", precision: "float64"),
            requiredContributors: [codec.schema], capacity: capacity, determinism: .sameBuildReplay, workload: "periodic-fluid")
        session = try Session(model: model, configuration: configuration, initialState: descriptor.initialState,
            contributors: [record], seed: 123,
            checkpoints: Handler(codec: codec, revisions: ReferenceModelRevisionUpdater()))
    }

    static func byteWork() throws -> PlanarContinuationWork {
        try PlanarContinuationWork(maximumStorageBytes: 30000, maximumWorkUnits: 100000)
    }

    @inline(never)
    func advance(decision: RuntimeTrialDecision = .accept, iterations: Int = 10000) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        let model = self.model, operation = self.operation, policy = self.policy
        return try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            _ = try trial.nextRandom()
            var numerical: NumericalWork, bytes: PlanarContinuationWork
            let source: PlanarSource
            do {
                numerical = NumericalWork(budget: try NumericalBudget(scalarStorage: 100000,
                    arithmeticOperations: 10000000, iterations: iterations))
                bytes = try Self.byteWork()
                source = try PlanarProbeContext.source()
            } catch { throw RuntimeFailure(.invalidInput, message: "Planar public probe budget construction failed.") }
            _ = try operation.advance(model: model, source: source, duration: 0.01, policy: policy,
                trial: &trial, control: &control, numerical: &numerical, continuation: &bytes)
            return decision
        }
    }

    @inline(never)
    func accepted() throws -> PlanarState {
        let records = session.snapshot().checkpoint.contributors
        guard records.count == 1 else { throw FoundationVerificationError.analyticCheckFailed }
        var bytes = try Self.byteWork()
        let operation: any PlanarContinuationCoding = codec
        return try operation.decode(records[0], work: &bytes)
    }
}
