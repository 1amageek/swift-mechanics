import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum GeometricEvolutionProbeContext {
    typealias Session = RuntimeSession<ReferenceRuntimeCheckpointHandler<IntegrationContinuationProvider, ReferenceModelRevisionUpdater>>

    @inline(never)
    static func equation(_ fixture: FourBarProbeModel) throws -> GeometricMechanismEquation {
        let system = try GeometricProbeContext.system(fixture), projection = try GeometricProbeContext.policy()
        let tolerance = try LinearTolerance<Double>(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-13)
        let position = projection.constraints
        let constraints = try ConstraintSolvePolicy(evaluation: position.evaluation,
            diagonalMetric: position.diagonalMetric, energyScale: position.energyScale, rankPolicy: position.rankPolicy,
            rankRelativeTolerance: position.rankRelativeTolerance, originalResidualTolerance: position.originalResidualTolerance,
            maximumCorrection: position.maximumCorrection, nonlinear: position.nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            linearTolerance: position.linearTolerance)
        let solve = try MechanismSolvePolicy(dynamics: DynamicsSolvePolicy(
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: tolerance, coordinateScales: system.layout.scales, energyScale: 7, timeScale: system.layout.timeScale),
            constraints: constraints, maximumCoordinates: 3, maximumRows: 3, originalTolerance: 1e-8)
        var drive = [Double](repeating: 0, count: system.layout.scales.count)
        drive[fixture.crankIndex] = 1
        return try GeometricMechanismEquation(identity: "four-bar-torque-public", geometry: system, drive: drive,
            policy: solve, projection: projection, maximumStageChartCorrection: 0.05,
            publicationBudget: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000),
            admission: MechanismProbeContext.admission(), maximumIdentityBytes: 65536)
    }

    static func policy(_ equation: GeometricMechanismEquation) throws -> ExplicitIntegrationPolicy {
        let scales = try equation.descriptor.dimensions.map { try ODEErrorScale(dimension: $0, absoluteSI: 1e-7, relative: 0) }
        return try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.01, minimumStep: 1e-8, maximumStep: 0.01,
            safety: 0.8, minimumFactor: 0.1, maximumFactor: 2, scales: scales, maximumContinuationBytes: 32768,
            budget: IntegrationBudget(maximumCoordinates: 6, maximumAttempts: 100, maximumAcceptedSteps: 100,
                maximumOuterArithmetic: 1_000_000,
                supplier: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000)))
    }

    @inline(never)
    static func session(_ fixture: FourBarProbeModel, equation: GeometricMechanismEquation) throws -> (Session, IntegrationContinuationProvider) {
        let provider = try IntegrationContinuationProvider(descriptor: equation.descriptor, policy: policy(equation))
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "four-bar-torque-public-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: provider.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4, maximumContributorBytes: 65536,
                maximumMetadataBytes: 65536, maximumCheckpointBytes: 131072, maximumValidationWork: 200000,
                maximumValidationScratchBytes: 131072, maximumObservationLeases: 2, maximumBatchStates: 2,
                maximumTransactions: 1000, maximumStepWorkUnits: 100000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "four-bar-torque")
        let handler = ReferenceRuntimeCheckpointHandler(contributors: provider, revisions: ReferenceModelRevisionUpdater())
        return (try Session(model: fixture.model, configuration: configuration, initialState: fixture.model.descriptor.initialState,
            contributors: [provider.initialRecord(physical: fixture.model.descriptor.initialState, equations: equation)],
            seed: 42, checkpoints: handler), provider)
    }
}
