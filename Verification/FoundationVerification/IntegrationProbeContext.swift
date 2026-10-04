import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct IntegrationProbeContext {
    typealias Session = RuntimeSession<ReferenceRuntimeCheckpointHandler<IntegrationContinuationProvider, ReferenceModelRevisionUpdater>>
    let fixture: MechanicalProbeModel
    let equation: IntegrationProbeEquation
    let continuation: IntegrationContinuationProvider
    let first: Session
    let second: Session

    @inline(never)
    init(method: ExplicitIntegrationMethod) throws {
        let fixture = try MechanicalProbeModel(), equation = try IntegrationProbeEquation(model: fixture.model)
        let policy = try ExplicitIntegrationPolicy(method: method, initialStep: 0.25, minimumStep: 1e-6, maximumStep: 0.25,
            safety: 0.8, minimumFactor: 0.1, maximumFactor: 2,
            scales: [ODEErrorScale(dimension: .angle, absoluteSI: 1e-4, relative: 0),
                ODEErrorScale(dimension: PhysicalDimension(time: -1, angle: 1), absoluteSI: 1e-4, relative: 0)],
            maximumContinuationBytes: 2048,
            budget: IntegrationBudget(maximumCoordinates: 2, maximumAttempts: 1000, maximumAcceptedSteps: 1000,
                maximumOuterArithmetic: 1000000, supplier: NumericalBudget(scalarStorage: 100, arithmeticOperations: 100000, iterations: 1000)))
        let continuation = try IntegrationContinuationProvider(descriptor: equation.descriptor, policy: policy)
        let handler = ReferenceRuntimeCheckpointHandler(contributors: continuation, revisions: ReferenceModelRevisionUpdater())
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "integration-profile-probe", backend: "reference-cpu", precision: "float64"),
            requiredContributors: continuation.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 3, maximumContributors: 1, maximumContributorBytes: 2048,
                maximumMetadataBytes: 4096, maximumCheckpointBytes: 8192, maximumValidationWork: 4096,
                maximumValidationScratchBytes: 100, maximumObservationLeases: 1, maximumBatchStates: 1,
                maximumTransactions: 2000, maximumStepWorkUnits: 1000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "constant-acceleration")
        let initial = try continuation.initialRecord(physical: fixture.descriptor.initialState, equations: equation)
        let first = try RuntimeSession(model: fixture.model, configuration: configuration, initialState: fixture.descriptor.initialState,
            contributors: [initial], seed: 7, checkpoints: handler)
        let second = try RuntimeSession(model: fixture.model, configuration: configuration, initialState: fixture.descriptor.initialState,
            contributors: [initial], seed: 7, checkpoints: handler)
        self.fixture = fixture; self.equation = equation; self.continuation = continuation
        self.first = first; self.second = second
    }
}
