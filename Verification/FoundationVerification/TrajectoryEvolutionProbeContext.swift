import SwiftMechanics

/// Immutable public composition; sampling, physical solve and Runtime publication have distinct phases.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class TrajectoryEvolutionProbeContext: Sendable {
    typealias Session = RuntimeSession<GeometricMechanismCheckpointHandler>
    let fixture: TrajectoryEvolutionProbeModel
    let geometry: GeometricConstraintSystem
    let solvePolicy: MechanismSolvePolicy
    let equation: GeometricMechanismEquation
    let initialState: KinematicState
    let provider: IntegrationContinuationProvider
    let configuration: RuntimeConfiguration
    let handler: GeometricMechanismCheckpointHandler
    let step: Double

    @inline(never)
    init(_ fixture: TrajectoryEvolutionProbeModel, step: Double = 0.01,
         sampler: any PrescribedBaseTrajectorySampling = AnalyticPrescribedBaseTrajectorySampler(),
         boundaryQuery: any PrescribedTrajectoryBoundaryQuerying = PrescribedTrajectoryBoundaryQuery()) throws {
        let geometry = try Self.geometry(fixture)
        let policy = try Self.policy(fixture)
        let equation = try Self.equation(fixture, geometry: geometry, policy: policy,
            sampler: sampler, boundaryQuery: boundaryQuery)
        let initial = try Self.initial(fixture, geometry: geometry, policy: policy)
        let provider = try Self.provider(equation, step: step)
        let configuration = try Self.configuration(provider)
        let handler = try Self.handler(equation, provider: provider)
        self.fixture = fixture; self.step = step; self.geometry = geometry; solvePolicy = policy
        self.equation = equation; initialState = initial; self.provider = provider
        self.configuration = configuration; self.handler = handler
    }

    @inline(never)
    private static func geometry(_ fixture: TrajectoryEvolutionProbeModel) throws -> GeometricConstraintSystem {
        let p = fixture.model.tree.layout.positionCount, n = fixture.model.tree.layout.velocityCount
        var work = try GeometricProbeContext.work()
        return try GeometricConstraintSystem(model: fixture.model, layout: fixture.layout, relations: [],
            minimumPosition: [Double](repeating: -100, count: p), maximumPosition: [Double](repeating: 100, count: p),
            minimumTime: 0, maximumTime: 2, capacity: GeometricConstraintCapacity(maximumBodies: 2,
                maximumPositions: p, maximumVelocities: n, maximumRows: n, maximumMetadataBytes: 65536),
            work: &work, prescribedBaseTrajectory: fixture.program)
    }

    private static func policy(_ fixture: TrajectoryEvolutionProbeModel) throws -> MechanismSolvePolicy {
        let original = try MechanismProbeContext.policy(), n = fixture.model.tree.layout.velocityCount
        let constraints = try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(
                maximumCoordinates: fixture.model.tree.layout.positionCount, maximumRows: n,
                expectedLayoutRevision: fixture.model.stamp.revision),
            diagonalMetric: [Double](repeating: 1, count: n), energyScale: 7,
            rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-9,
            maximumCorrection: 100, nonlinear: original.constraints.nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            linearTolerance: original.constraints.linearTolerance)
        let dynamics = try DynamicsSolvePolicy(capability: original.dynamics.capability,
            linearTolerance: original.dynamics.linearTolerance, coordinateScales: fixture.layout.scales,
            energyScale: 7, timeScale: fixture.layout.timeScale)
        return try MechanismSolvePolicy(dynamics: dynamics, constraints: constraints,
            maximumCoordinates: fixture.model.tree.layout.positionCount, maximumRows: n, originalTolerance: 1e-9)
    }

    @inline(never)
    private static func equation(_ fixture: TrajectoryEvolutionProbeModel, geometry: GeometricConstraintSystem,
                                 policy: MechanismSolvePolicy, sampler: any PrescribedBaseTrajectorySampling,
                                 boundaryQuery: any PrescribedTrajectoryBoundaryQuerying) throws -> GeometricMechanismEquation {
        let kernel = RigidEquationKernel()
        let solver: any PrescribedRootMechanismSolving = MassWeightedMechanismSolver(
            physicalDynamics: DenseRigidDynamics(physicalEquations: kernel), physicalEquations: kernel)
        let projection = try ManifoldProjectionPolicy(constraints: policy.constraints, maximumIterations: 20,
            maximumPathCorrection: 100, maximumMetadataBytes: 65536)
        return try GeometricMechanismEquation(identity: "af26-trajectory-evolution", geometry: geometry,
            drive: fixture.drive, policy: policy, projection: projection, maximumStageChartCorrection: 0.05,
            publicationBudget: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000),
            admission: MechanismProbeContext.admission(), maximumIdentityBytes: 65536,
            physicalKernel: kernel, prescribedRootSolver: solver, activeRanker: WeightedConstraintAssembler(),
            baseTrajectorySampler: sampler, powerPartitioner: kernel, boundaryQuery: boundaryQuery)
    }

    @inline(never)
    private static func initial(_ fixture: TrajectoryEvolutionProbeModel, geometry: GeometricConstraintSystem,
                                policy: MechanismSolvePolicy) throws -> KinematicState {
        let source = fixture.model.descriptor.initialState
        let motion = try Self.motion(source, fixture: fixture, geometry: geometry, policy: policy)
        return try KinematicState(revision: source.revision, time: source.time, q: source.q, v: source.v,
            acceleration: motion.motion.values)
    }

    @inline(never)
    func state(time: Double, relativePosition: Double = 0, relativeVelocity: Double = 0,
               relativeAcceleration: Double = 0) throws -> KinematicState {
        guard let binding = geometry.rootBinding else { throw FoundationVerificationError.analyticCheckFailed }
        var work = try GeometricProbeContext.work()
        let sample = try binding.sample(time: time, work: &work)
        var q = sample.q, v = sample.v, a = sample.a
        if fixture.descendant {
            q.append(relativePosition); v.append(relativeVelocity); a.append(relativeAcceleration)
        }
        return try KinematicState(revision: fixture.model.stamp.revision, time: time, q: q, v: v, acceleration: a)
    }

    @inline(never)
    func motion(_ state: KinematicState) throws -> PhysicalConstrainedMotion {
        try Self.motion(state, fixture: fixture, geometry: geometry, policy: solvePolicy)
    }

    @inline(never)
    private static func motion(_ state: KinematicState, fixture: TrajectoryEvolutionProbeModel,
                               geometry: GeometricConstraintSystem, policy: MechanismSolvePolicy) throws -> PhysicalConstrainedMotion {
        let original = try Self.original(state, geometry: geometry, policy: policy)
        let input = try Self.input(original, fixture: fixture, state: state)
        let system = try Self.assemble(input)
        return try Self.solve(system, original: original, fixture: fixture, geometry: geometry, policy: policy)
    }

    @inline(never)
    private static func original(_ state: KinematicState, geometry: GeometricConstraintSystem,
                                 policy: MechanismSolvePolicy) throws -> HolonomicGeometrySample {
        var work = try GeometricProbeContext.work()
        let service: any HolonomicGeometryProviding = GeometricRelationEvaluator()
        return try service.evaluate(geometry, state: state, policy: policy.constraints.evaluation, work: &work)
    }

    @inline(never)
    private static func input(_ original: HolonomicGeometrySample, fixture: TrajectoryEvolutionProbeModel,
                              state: KinematicState) throws -> PhysicalRigidDynamicsInput {
        if fixture.planar {
            var inertias: [PlanarRigidBodyInertia] = []
            for body in original.snapshot.bodies {
                guard let source = fixture.model.descriptor.bodies.first(where: { $0.id == body.body }),
                      source.frame == body.bodyFrame, case .planar(let record) = source,
                      let inertia = record.inertia else {
                    throw DynamicsError.inertiaIdentityMismatch
                }
                inertias.append(try PlanarRigidBodyInertia(body: record.id, frame: record.frame, properties: inertia.properties))
            }
            return try PhysicalRigidDynamicsInput(planar: PlanarRigidDynamicsInput(snapshot: original.snapshot,
                velocity: state.v, inertias: inertias, gravity: nil))
        }
        var inertias: [RigidBodyInertia] = []
        for body in original.snapshot.bodies {
            guard let source = fixture.model.descriptor.bodies.first(where: { $0.id == body.body }),
                  source.frame == body.bodyFrame, case .spatial(let record) = source,
                  let inertia = record.inertia else {
                throw DynamicsError.inertiaIdentityMismatch
            }
            inertias.append(try RigidBodyInertia(body: record.id, frame: record.frame, properties: inertia.properties))
        }
        return try PhysicalRigidDynamicsInput(spatial: RigidDynamicsInput(snapshot: original.snapshot,
            velocity: state.v, inertias: inertias, gravity: nil))
    }

    @inline(never)
    private static func assemble(_ input: PhysicalRigidDynamicsInput) throws -> PhysicalRigidDynamicsSystem {
        var work = try GeometricProbeContext.work()
        var load = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 100))
        let service: any PhysicalRigidEquationComputing = RigidEquationKernel()
        return try service.assemble(input, admission: MechanismProbeContext.admission(), loadWork: &load, work: &work)
    }

    @inline(never)
    private static func solve(_ system: PhysicalRigidDynamicsSystem, original: HolonomicGeometrySample,
                              fixture: TrajectoryEvolutionProbeModel, geometry: GeometricConstraintSystem,
                              policy: MechanismSolvePolicy) throws -> PhysicalConstrainedMotion {
        guard let binding = geometry.rootBinding else { throw FoundationVerificationError.analyticCheckFailed }
        var work = try GeometricProbeContext.work(), dynamics = try GeometricProbeContext.work()
        var rank = try GeometricProbeContext.work(), linear = try GeometricProbeContext.work()
        let base = try binding.sample(time: system.input.snapshot.time, work: &work)
        let constraint = try PrescribedRootConstraint(system: system, geometry: original.velocity, base: base,
            rowIDs: binding.rowIDs, policy: policy, work: &work)
        let kernel = RigidEquationKernel()
        let service: any PrescribedRootMechanismSolving = MassWeightedMechanismSolver(
            physicalDynamics: DenseRigidDynamics(physicalEquations: kernel), physicalEquations: kernel)
        return try service.acceleration(constraint, drive: fixture.drive, policy: policy,
            work: &work, dynamicsWork: &dynamics, rankWork: &rank, linearWork: &linear)
    }

    @inline(never)
    func power(_ motion: PhysicalConstrainedMotion) throws -> PartitionedMechanicalPower {
        guard let binding = geometry.rootBinding else { throw FoundationVerificationError.analyticCheckFailed }
        var work = try GeometricProbeContext.work()
        let service: any PhysicalPowerPartitioning = RigidEquationKernel()
        return try service.partitionedPower(motion.system, acceleration: motion.motion.values,
            knownCoordinates: binding.knownCoordinates, drive: fixture.drive,
            geometricReaction: [Double](repeating: 0, count: fixture.drive.count), policy: solvePolicy.dynamics, work: &work)
    }

    @inline(never)
    private static func provider(_ equation: GeometricMechanismEquation, step: Double) throws -> IntegrationContinuationProvider {
        let scales = try equation.descriptor.dimensions.map { try ODEErrorScale(dimension: $0, absoluteSI: 1e-7, relative: 0) }
        let policy = try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: step, minimumStep: 1e-8,
            maximumStep: step, safety: 0.8, minimumFactor: 0.1, maximumFactor: 2, scales: scales,
            maximumContinuationBytes: 65536, budget: IntegrationBudget(maximumCoordinates: equation.descriptor.dimensions.count,
                maximumAttempts: 1000, maximumAcceptedSteps: 1000, maximumOuterArithmetic: 1_000_000,
                supplier: equation.publicationBudget))
        return try IntegrationContinuationProvider(descriptor: equation.descriptor, policy: policy)
    }

    private static func configuration(_ provider: IntegrationContinuationProvider) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "af26-trajectory-public-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: provider.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4, maximumContributorBytes: 131072,
                maximumMetadataBytes: 131072, maximumCheckpointBytes: 262144, maximumValidationWork: 400000,
                maximumValidationScratchBytes: 262144, maximumObservationLeases: 2, maximumBatchStates: 2,
                maximumTransactions: 10000, maximumStepWorkUnits: 100000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "af26-law-bound-root-evolution")
    }

    @inline(never)
    private static func handler(_ equation: GeometricMechanismEquation,
                                provider: IntegrationContinuationProvider) throws -> GeometricMechanismCheckpointHandler {
        let base = ReferenceRuntimeCheckpointHandler(contributors: provider, revisions: ReferenceModelRevisionUpdater())
        return try GeometricMechanismCheckpointHandler(equations: equation, continuation: provider,
            base: base, validationBudget: equation.publicationBudget)
    }

    @inline(never)
    func session() throws -> Session {
        try Session(model: fixture.model, configuration: configuration, initialState: initialState,
            contributors: [provider.initialRecord(physical: initialState, equations: equation)], seed: 42, checkpoints: handler)
    }

    @inline(never)
    func advance(_ session: Session, to time: Double) throws(NonlinearMechanismFailure) -> NonlinearMechanismAdvanceResult {
        let service: any ProjectedMechanismEvolving = ProjectedNonlinearMechanismEvolution()
        return try service.advance(session, equations: equation, continuation: provider, to: time)
    }

    @inline(never)
    func inspect(_ session: Session,
                 using operation: @Sendable (NonlinearMechanismState) throws(RuntimeFailure) -> Void) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        let equation = self.equation
        return try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            var work = NumericalWork(budget: equation.publicationBudget)
            var point = [Double](repeating: 0, count: equation.descriptor.dimensions.count)
            try equation.read(trial, into: &point)
            let proof = try equation.consistent(time: trial.timeSeconds, point: point, work: &work, control: control)
            try operation(proof)
            return .reject
        }
    }

    @inline(never)
    func checkpoint(_ session: Session) throws -> [UInt8] {
        try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
    }

    @inline(never)
    func restore(_ session: Session, bytes: [UInt8]) throws -> RuntimeAcceptedState {
        try session.restart(bytes, codec: NativeRuntimeCheckpointCodec())
    }

    @inline(never)
    func history(_ session: Session) throws -> IntegrationHistory {
        let accepted = session.snapshot()
        guard let record = accepted.checkpoint.contributors.first(where: { $0.id == provider.schema.id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return try provider.associatedHistory(record, physical: accepted.checkpoint.physical, equations: equation)
    }

    @inline(never)
    func fresh() throws -> TrajectoryEvolutionProbeContext {
        try TrajectoryEvolutionProbeContext(TrajectoryEvolutionProbeModel(planar: fixture.planar,
            piecewise: fixture.piecewise, descendant: fixture.descendant,
            futureAngularOffset: fixture.futureAngularOffset, descendantDrive: fixture.descendantDrive), step: step)
    }

    @inline(never)
    func changedFutureLaw(offset: Double) throws -> TrajectoryEvolutionProbeContext {
        try TrajectoryEvolutionProbeContext(TrajectoryEvolutionProbeModel(planar: fixture.planar,
            piecewise: fixture.piecewise, descendant: fixture.descendant,
            futureAngularOffset: offset, descendantDrive: fixture.descendantDrive), step: step)
    }
}
