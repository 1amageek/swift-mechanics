import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum NonlinearMechanismProbeContext {
    typealias Session = RuntimeSession<ReferenceRuntimeCheckpointHandler<IntegrationContinuationProvider, ReferenceModelRevisionUpdater>>

    static func equation(_ model: CompiledMechanicalModel) throws -> NonlinearMechanismEquation {
        let layout = try MechanismProbeContext.layout(), solve = try MechanismProbeContext.policy()
        let row = QuadraticConstraint(id: 1, constant: -1, linear: [0, 0], hessian: [8, 0, 0, 18],
                                      timeLinear: 0, timeQuadratic: 0, mixedTime: [0, 0])
        let constraints = try QuadraticConstraintSystem(layout: layout, rows: [row], minimumPosition: [-2, -2],
                                                       maximumPosition: [2, 2], minimumTime: 0, maximumTime: 10)
        return try NonlinearMechanismEquation(identity: "physical-nonlinear-angular-coupling", model: model,
                                             constraints: constraints, velocityLayout: layout, drive: [0, 0], policy: solve,
                                             projection: NonlinearMechanismProjectionPolicy(position: solve.constraints,
                                                                                           maximumIterations: 32, maximumCorrection: 1),
                                             admission: MechanismProbeContext.admission(), maximumIdentityBytes: 8192)
    }

    static func policy() throws -> ExplicitIntegrationPolicy {
        try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.02, minimumStep: 1e-8, maximumStep: 0.02,
                                      safety: 0.8, minimumFactor: 0.1, maximumFactor: 2,
                                      scales: [.init(dimension: .angle, absoluteSI: 1e-7, relative: 0),
                                               .init(dimension: .angle, absoluteSI: 1e-7, relative: 0),
                                               .init(dimension: PhysicalDimension(time: -1, angle: 1), absoluteSI: 1e-7, relative: 0),
                                               .init(dimension: PhysicalDimension(time: -1, angle: 1), absoluteSI: 1e-7, relative: 0)],
                                      maximumContinuationBytes: 16_384,
                                      budget: IntegrationBudget(maximumCoordinates: 4, maximumAttempts: 100, maximumAcceptedSteps: 100,
                                                                maximumOuterArithmetic: 1_000_000,
                                                                supplier: NumericalBudget(scalarStorage: 1_000_000,
                                                                                          arithmeticOperations: 100_000_000, iterations: 100_000)))
    }

    static func session(_ model: CompiledMechanicalModel, equation: NonlinearMechanismEquation) throws -> (Session, IntegrationContinuationProvider) {
        let continuation = try IntegrationContinuationProvider(descriptor: equation.descriptor, policy: policy())
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "nonlinear-mechanism-v1",
                                                                                               backend: "reference-cpu", precision: "float64"),
                                                     requiredContributors: continuation.schemas,
                                                     capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4,
                                                                               maximumContributorBytes: 32_768, maximumMetadataBytes: 16_384,
                                                                               maximumCheckpointBytes: 65_536, maximumValidationWork: 100_000,
                                                                               maximumValidationScratchBytes: 100_000, maximumObservationLeases: 2,
                                                                               maximumBatchStates: 2, maximumTransactions: 1000,
                                                                               maximumStepWorkUnits: 100_000, maximumWorkBetweenSafePoints: 4),
                                                     determinism: .sameBuildReplay, workload: "physical-nonlinear-angular-coupling")
        let handler = try ReferenceRuntimeCheckpointHandler(contributors: continuation, revisions: ReferenceModelRevisionUpdater())
        return (try Session(model: model, configuration: configuration, initialState: model.descriptor.initialState,
                            contributors: [continuation.initialRecord(physical: model.descriptor.initialState, equations: equation)],
                            seed: 42, checkpoints: handler), continuation)
    }
}
