import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class PrescribedRotorProbeContext: Sendable {
    typealias Session = RuntimeSession<GeometricMechanismCheckpointHandler>
    let fixture: PrescribedRotorProbeModel
    let geometry: GeometricConstraintSystem

    @inline(never)
    init(_ fixture: PrescribedRotorProbeModel) throws {
        self.fixture = fixture
        geometry = try Self.geometry(fixture)
    }

    @inline(never)
    private static func geometry(_ fixture: PrescribedRotorProbeModel) throws -> GeometricConstraintSystem {
        let first = try GeometricFrameEndpoint(body: fixture.firstRotor, frame: fixture.firstRotorFrame, point: .zero, axis: .unitX)
        let second = try GeometricFrameEndpoint(body: fixture.secondRotor, frame: fixture.secondRotorFrame, point: .zero, axis: .unitX)
        let relation = try GeometricRelation(kind: .alignedAxes, rowIDs: [41, 42], first: first, second: second,
            target: GeometricAnalyticTarget(), scale: 1)
        var work = try GeometricProbeContext.work()
        let p = fixture.model.tree.layout.positionCount
        return try GeometricConstraintSystem(model: fixture.model, layout: fixture.layout, relations: [relation],
            minimumPosition: [Double](repeating: -100, count: p), maximumPosition: [Double](repeating: 100, count: p),
            minimumTime: 0, maximumTime: 2, capacity: GeometricConstraintCapacity(maximumBodies: 3,
                maximumPositions: 9, maximumVelocities: 8, maximumRows: 12, maximumMetadataBytes: 65536),
            work: &work, prescribedBase: fixture.base)
    }

    @inline(never)
    func state(time: Double, relativePosition: Double, relativeVelocity: Double, relativeAcceleration: Double) throws -> KinematicState {
        guard let binding = geometry.prescribedRoot else { throw FoundationVerificationError.analyticCheckFailed }
        var work = try GeometricProbeContext.work()
        let sample = try binding.sample(time: time, work: &work)
        var q = fixture.model.descriptor.initialState.q, v = fixture.model.descriptor.initialState.v
        var a = fixture.model.descriptor.initialState.acceleration
        for index in sample.q.indices { q[index] = sample.q[index] }
        for index in sample.v.indices { v[index] = sample.v[index]; a[index] = sample.a[index] }
        q[fixture.firstPosition] = relativePosition; q[fixture.secondPosition] = relativePosition
        v[fixture.firstVelocity] = relativeVelocity; v[fixture.secondVelocity] = relativeVelocity
        a[fixture.firstVelocity] = relativeAcceleration; a[fixture.secondVelocity] = relativeAcceleration
        return try KinematicState(revision: fixture.model.stamp.revision, time: time, q: q, v: v, acceleration: a)
    }

    func policy() throws -> MechanismSolvePolicy {
        let original = try MechanismProbeContext.policy()
        let constraints = try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 9,
                maximumRows: 12, expectedLayoutRevision: fixture.model.stamp.revision),
            diagonalMetric: [Double](repeating: 1, count: fixture.layout.scales.count), energyScale: 7,
            rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-8,
            maximumCorrection: 100, nonlinear: original.constraints.nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            linearTolerance: original.constraints.linearTolerance)
        let dynamics = try DynamicsSolvePolicy(capability: original.dynamics.capability,
            linearTolerance: original.dynamics.linearTolerance, coordinateScales: fixture.layout.scales,
            energyScale: 7, timeScale: fixture.layout.timeScale)
        return try MechanismSolvePolicy(dynamics: dynamics, constraints: constraints, maximumCoordinates: 9,
            maximumRows: 12, originalTolerance: 1e-8)
    }

    @inline(never)
    func equation() throws -> GeometricMechanismEquation {
        let solve = try policy()
        let projection = try ManifoldProjectionPolicy(constraints: solve.constraints, maximumIterations: 20,
            maximumPathCorrection: 100, maximumMetadataBytes: 65536)
        var drive = [Double](repeating: 0, count: fixture.model.tree.layout.velocityCount)
        drive[fixture.firstVelocity] = 1
        let kernel = RigidEquationKernel()
        let solver: any PrescribedRootMechanismSolving = MassWeightedMechanismSolver(
            physicalDynamics: DenseRigidDynamics(physicalEquations: kernel), physicalEquations: kernel)
        return try GeometricMechanismEquation(identity: fixture.planar ? "prescribed-planar-rotors-equation" : "prescribed-spatial-rotors-equation",
            geometry: geometry, drive: drive, policy: solve, projection: projection, maximumStageChartCorrection: 0.05,
            publicationBudget: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000),
            admission: MechanismProbeContext.admission(), maximumIdentityBytes: 65536,
            physicalKernel: kernel, prescribedRootSolver: solver, activeRanker: WeightedConstraintAssembler(), powerPartitioner: kernel)
    }

    func integrationPolicy(_ equation: GeometricMechanismEquation, step: Double = 0.01) throws -> ExplicitIntegrationPolicy {
        let scales = try equation.descriptor.dimensions.map { try ODEErrorScale(dimension: $0, absoluteSI: 1e-7, relative: 0) }
        return try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: step, minimumStep: 1e-8, maximumStep: step,
            safety: 0.8, minimumFactor: 0.1, maximumFactor: 2, scales: scales, maximumContinuationBytes: 32768,
            budget: IntegrationBudget(maximumCoordinates: equation.descriptor.dimensions.count, maximumAttempts: 100, maximumAcceptedSteps: 100,
                maximumOuterArithmetic: 1_000_000,
                supplier: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000)))
    }

    @inline(never)
    func session(equation: GeometricMechanismEquation) throws -> (Session, IntegrationContinuationProvider) {
        let provider = try IntegrationContinuationProvider(descriptor: equation.descriptor, policy: integrationPolicy(equation))
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "prescribed-rotors-public-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: provider.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4, maximumContributorBytes: 65536,
                maximumMetadataBytes: 65536, maximumCheckpointBytes: 131072, maximumValidationWork: 200000,
                maximumValidationScratchBytes: 131072, maximumObservationLeases: 2, maximumBatchStates: 2,
                maximumTransactions: 1000, maximumStepWorkUnits: 100000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "prescribed-root-descendant-rotors")
        let base = ReferenceRuntimeCheckpointHandler(contributors: provider, revisions: ReferenceModelRevisionUpdater())
        let handler = try GeometricMechanismCheckpointHandler(equations: equation, continuation: provider, base: base,
            validationBudget: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000))
        return (try Session(model: fixture.model, configuration: configuration, initialState: fixture.model.descriptor.initialState,
            contributors: [provider.initialRecord(physical: fixture.model.descriptor.initialState, equations: equation)],
            seed: 42, checkpoints: handler), provider)
    }
}
