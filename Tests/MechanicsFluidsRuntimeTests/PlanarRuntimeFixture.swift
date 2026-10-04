import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct PlanarRuntimeFixture {
    typealias Handler = PlanarRuntimeCheckpointHandler<ReferenceModelRevisionUpdater>
    typealias Session = RuntimeSession<Handler>
    let model: CompiledMechanicalModel
    let grid: PlanarGrid
    let codec: FixedPlanarContinuationCodec
    let operation: ReferencePlanarTrialOperator
    let session: Session
    init(time: Double = 0, sequence: UInt64 = 0, stepWork: Int = 4, shear: Bool = false,
         flow: any PlanarFlowOperating = ReferencePlanarFlowSolver(linear: ReferenceLinearSolver<Double>())) throws {
        let model = try PlanarRuntimeFixtures.model(), grid = try PlanarRuntimeFixtures.grid()
        let codec = try PlanarRuntimeFixtures.codec(grid: grid, model: model.stamp)
        let capacity = try RuntimeCapacity(maximumPhysicalScalars: 0, maximumContributors: 1, maximumContributorBytes: 8192,
            maximumMetadataBytes: 2048, maximumCheckpointBytes: 16384, maximumValidationWork: 100000,
            maximumValidationScratchBytes: 30000, maximumObservationLeases: 1, maximumBatchStates: 1,
            maximumTransactions: 100, maximumStepWorkUnits: stepWork, maximumWorkBetweenSafePoints: 1)
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "planar-v1", backend: "reference-cpu", precision: "float64"),
            requiredContributors: [codec.schema], capacity: capacity, determinism: .sameBuildReplay, workload: "periodic-fluid")
        let handler = Handler(codec: codec, revisions: ReferenceModelRevisionUpdater())
        let initial = try PlanarRuntimeFixtures.state(grid, time: time, sequence: sequence, shear: shear)
        var bytes = try PlanarRuntimeFixtures.bytes()
        let record = try codec.encode(initial, work: &bytes)
        self.model = model; self.grid = grid; self.codec = codec
        self.operation = ReferencePlanarTrialOperator(codec: codec, flow: flow)
        self.session = try Session(model: model, configuration: configuration, initialState: model.descriptor.initialState,
                                   contributors: [record], seed: 123, checkpoints: handler)
    }
    func advance(duration: Double = 0.01, decision: RuntimeTrialDecision = .accept) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        let model = self.model, operation = self.operation
        return try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            _ = try trial.nextRandom()
            var numerical: NumericalWork, bytes: PlanarContinuationWork
            let source: PlanarSource, policy: PlanarPolicy
            do {
                numerical = try PlanarRuntimeFixtures.numerical(); bytes = try PlanarRuntimeFixtures.bytes()
                source = try PlanarRuntimeFixtures.source(); policy = try PlanarRuntimeFixtures.policy()
            } catch { throw RuntimeFailure(.invalidInput, message: "Fixture budget/policy construction failed.") }
            _ = try operation.advance(model: model, source: source, duration: duration, policy: policy,
                                      trial: &trial, control: &control, numerical: &numerical, continuation: &bytes)
            return decision
        }
    }
    func accepted() throws -> PlanarState {
        let records = session.snapshot().checkpoint.contributors
        guard records.count == 1 else { throw RuntimeFailure(.missingContributor, message: "Fixture fluid field is missing.") }
        var bytes = try PlanarRuntimeFixtures.bytes(); return try codec.decode(records[0], work: &bytes)
    }
}
