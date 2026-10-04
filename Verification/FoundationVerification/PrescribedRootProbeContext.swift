import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class PrescribedRootProbeContext: Sendable {
    typealias Session = RuntimeSession<GeometricMechanismCheckpointHandler>
    let fixture: PrescribedRootProbeModel
    let geometry: GeometricConstraintSystem

    @inline(never)
    init(_ fixture: PrescribedRootProbeModel) throws {
        self.fixture = fixture
        geometry = try Self.geometry(fixture)
    }

    @inline(never)
    private static func geometry(_ fixture: PrescribedRootProbeModel) throws -> GeometricConstraintSystem {
        let p = fixture.model.tree.layout.positionCount
        var work = try GeometricProbeContext.work()
        return try GeometricConstraintSystem(model: fixture.model, layout: fixture.layout, relations: [],
            minimumPosition: [Double](repeating: -10, count: p), maximumPosition: [Double](repeating: 10, count: p),
            minimumTime: 0, maximumTime: 2, capacity: GeometricConstraintCapacity(maximumBodies: 1,
                maximumPositions: 7, maximumVelocities: 6, maximumRows: 6, maximumMetadataBytes: 32768),
            work: &work, prescribedBase: fixture.base)
    }

    @inline(never)
    func state(time: Double) throws -> KinematicState {
        guard let binding = geometry.prescribedRoot else { throw FoundationVerificationError.analyticCheckFailed }
        var work = try GeometricProbeContext.work()
        let sample = try binding.sample(time: time, work: &work)
        return try KinematicState(revision: 1, time: time, q: sample.q, v: sample.v, acceleration: sample.a)
    }

    @inline(never)
    private func original(_ state: KinematicState) throws -> HolonomicGeometrySample {
        var work = try GeometricProbeContext.work()
        let service: any HolonomicGeometryProviding = GeometricRelationEvaluator()
        return try service.evaluate(geometry, state: state, policy: policy().constraints.evaluation, work: &work)
    }

    @inline(never)
    private func input(_ original: HolonomicGeometrySample, state: KinematicState) throws -> PhysicalRigidDynamicsInput {
        guard let body = fixture.model.descriptor.bodies.first else { throw FoundationVerificationError.analyticCheckFailed }
        switch body {
        case .planar(let record):
            guard let inertia = record.inertia else { throw FoundationVerificationError.analyticCheckFailed }
            let item = try PlanarRigidBodyInertia(body: record.id, frame: record.frame, properties: inertia.properties)
            return try PhysicalRigidDynamicsInput(planar: PlanarRigidDynamicsInput(snapshot: original.snapshot,
                velocity: state.v, inertias: [item], gravity: nil))
        case .spatial(let record):
            guard let inertia = record.inertia else { throw FoundationVerificationError.analyticCheckFailed }
            let item = try RigidBodyInertia(body: record.id, frame: record.frame, properties: inertia.properties)
            return try PhysicalRigidDynamicsInput(spatial: RigidDynamicsInput(snapshot: original.snapshot,
                velocity: state.v, inertias: [item], gravity: nil))
        }
    }

    @inline(never)
    private func assemble(_ input: PhysicalRigidDynamicsInput) throws -> PhysicalRigidDynamicsSystem {
        var work = try GeometricProbeContext.work()
        var load = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 100))
        let service: any PhysicalRigidEquationComputing = RigidEquationKernel()
        return try service.assemble(input, admission: PlanarPhysicalProbeContext.admission(), loadWork: &load, work: &work)
    }

    @inline(never)
    func motion(time: Double) throws -> PhysicalConstrainedMotion {
        let state = try state(time: time)
        let original = try original(state)
        let system = try assemble(input(original, state: state))
        return try solve(system, original: original, time: time)
    }

    @inline(never)
    private func solve(_ system: PhysicalRigidDynamicsSystem, original: HolonomicGeometrySample,
                       time: Double) throws -> PhysicalConstrainedMotion {
        guard let binding = geometry.prescribedRoot else { throw FoundationVerificationError.analyticCheckFailed }
        var work = try GeometricProbeContext.work()
        let base = try binding.sample(time: time, work: &work), policy = try policy()
        let source = try PrescribedRootConstraint(system: system, geometry: original.velocity, base: base,
            rowIDs: binding.rowIDs, policy: policy, work: &work)
        var dynamic = try GeometricProbeContext.work(), rank = try GeometricProbeContext.work()
        var linear = try GeometricProbeContext.work()
        let service: any PrescribedRootMechanismSolving = MassWeightedMechanismSolver(
            physicalDynamics: DenseRigidDynamics(physicalEquations: RigidEquationKernel()), physicalEquations: RigidEquationKernel())
        return try service.acceleration(source, drive: [Double](repeating: 0, count: base.v.count),
            policy: policy, work: &work, dynamicsWork: &dynamic, rankWork: &rank, linearWork: &linear)
    }

    func policy() throws -> MechanismSolvePolicy {
        let base = try MechanismProbeContext.policy()
        let constraints = try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 7,
                maximumRows: 12, expectedLayoutRevision: 1),
            diagonalMetric: [Double](repeating: 1, count: fixture.layout.scales.count), energyScale: 7,
            rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-9,
            maximumCorrection: 10, nonlinear: base.constraints.nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU), linearTolerance: base.constraints.linearTolerance)
        let dynamics = try DynamicsSolvePolicy(capability: base.dynamics.capability,
            linearTolerance: base.dynamics.linearTolerance, coordinateScales: fixture.layout.scales,
            energyScale: 7, timeScale: fixture.layout.timeScale)
        return try MechanismSolvePolicy(dynamics: dynamics, constraints: constraints, maximumCoordinates: 7,
            maximumRows: 12, originalTolerance: 1e-9)
    }

    @inline(never)
    func power(_ motion: PhysicalConstrainedMotion) throws -> PartitionedMechanicalPower {
        guard let binding = geometry.prescribedRoot else { throw FoundationVerificationError.analyticCheckFailed }
        var work = try GeometricProbeContext.work()
        let service: any PhysicalPowerPartitioning = RigidEquationKernel()
        let zero = [Double](repeating: 0, count: fixture.layout.scales.count)
        return try service.partitionedPower(motion.system, acceleration: motion.motion.values,
            knownCoordinates: binding.knownCoordinates, drive: zero, geometricReaction: zero,
            policy: policy().dynamics, work: &work)
    }

    @inline(never)
    func equation() throws -> GeometricMechanismEquation {
        let solve = try policy()
        let projection = try ManifoldProjectionPolicy(constraints: solve.constraints, maximumIterations: 20,
            maximumPathCorrection: 10, maximumMetadataBytes: 65536)
        return try GeometricMechanismEquation(identity: "af25-root-only-evolution", geometry: geometry,
            drive: [Double](repeating: 0, count: fixture.layout.scales.count), policy: solve, projection: projection,
            maximumStageChartCorrection: 0.05,
            publicationBudget: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000),
            admission: PlanarPhysicalProbeContext.admission(), maximumIdentityBytes: 65536,
            physicalKernel: RigidEquationKernel(), prescribedRootSolver: MassWeightedMechanismSolver(
                physicalDynamics: DenseRigidDynamics(physicalEquations: RigidEquationKernel()), physicalEquations: RigidEquationKernel()),
            activeRanker: WeightedConstraintAssembler())
    }

    @inline(never)
    func session(_ equation: GeometricMechanismEquation) throws -> (Session, IntegrationContinuationProvider) {
        let scales = try equation.descriptor.dimensions.map { try ODEErrorScale(dimension: $0, absoluteSI: 1e-7, relative: 0) }
        let policy = try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.01, minimumStep: 1e-8,
            maximumStep: 0.01, safety: 0.8, minimumFactor: 0.1, maximumFactor: 2, scales: scales,
            maximumContinuationBytes: 32768, budget: IntegrationBudget(maximumCoordinates: equation.descriptor.dimensions.count,
                maximumAttempts: 100, maximumAcceptedSteps: 100, maximumOuterArithmetic: 1_000_000,
                supplier: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000)))
        let provider = try IntegrationContinuationProvider(descriptor: equation.descriptor, policy: policy)
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "af25-root-only-public-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: provider.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4, maximumContributorBytes: 65536,
                maximumMetadataBytes: 65536, maximumCheckpointBytes: 131072, maximumValidationWork: 200000,
                maximumValidationScratchBytes: 131072, maximumObservationLeases: 2, maximumBatchStates: 2,
                maximumTransactions: 1000, maximumStepWorkUnits: 100000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "af25-root-only-evolution")
        let base = ReferenceRuntimeCheckpointHandler(contributors: provider, revisions: ReferenceModelRevisionUpdater())
        let handler = try GeometricMechanismCheckpointHandler(equations: equation, continuation: provider, base: base,
            validationBudget: equation.publicationBudget)
        let initial = fixture.model.descriptor.initialState
        return (try Session(model: fixture.model, configuration: configuration, initialState: initial,
            contributors: [provider.initialRecord(physical: initial, equations: equation)], seed: 42, checkpoints: handler), provider)
    }
}
