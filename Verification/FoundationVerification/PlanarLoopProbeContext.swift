import SwiftMechanics

/// Retains immutable actual sources while each expensive operation owns its stack phase.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class PlanarLoopProbeContext: Sendable {
    let fixture: PlanarLoopProbeModel
    let geometry: GeometricConstraintSystem
    let physicalRows: GeometricPhysicalRowWitness
    let allocation: GeometricPhysicalAllocationWitness
    let dynamics: PhysicalRigidDynamicsSystem
    let motion: PhysicalConstrainedMotion

    @inline(never)
    init(fixture: PlanarLoopProbeModel, scale: Double = 2) throws {
        self.fixture = fixture
        let geometry = try Self.geometry(fixture, scale: scale)
        self.geometry = geometry
        let physicalRows = try Self.rows(geometry, state: fixture.model.descriptor.initialState)
        self.physicalRows = physicalRows
        allocation = try Self.allocate(geometry, state: fixture.model.descriptor.initialState, rows: physicalRows)
        let dynamics = try Self.assemble(fixture)
        self.dynamics = dynamics
        motion = try Self.solve(dynamics, rows: physicalRows)
    }

    @inline(never)
    static func geometry(_ fixture: PlanarLoopProbeModel, scale: Double = 2, duplicate: Bool = false) throws -> GeometricConstraintSystem {
        let first = try GeometricFrameEndpoint(body: fixture.coupler,
            frame: EntityID(kind: .frame, key: fixture.coupler.key + "-frame"), point: Vector3(2, 0, 0))
        let second = try GeometricFrameEndpoint(body: fixture.rocker,
            frame: EntityID(kind: .frame, key: fixture.rocker.key + "-frame"), point: Vector3(1, 0, 0))
        let target = try GeometricAnalyticTarget()
        var relations = [try GeometricRelation(kind: .coincidence, rowIDs: [11, 12, 13], first: first,
            second: second, target: target, scale: scale)]
        if duplicate {
            relations.append(try GeometricRelation(kind: .coincidence, rowIDs: [21, 22, 23], first: first,
                second: second, target: target, scale: scale))
        }
        let layout = try ConstraintCoordinateLayout(coordinateIDs: [101, 102, 103], dimensions: [.angle, .angle, .angle],
            scales: [2, 3, 4], timeScale: 2, revision: 1)
        var work = try MechanismProbeContext.work()
        return try GeometricConstraintSystem(model: fixture.model, layout: layout, relations: relations,
            minimumPosition: [-5, -5, -5], maximumPosition: [5, 5, 5], minimumTime: 0, maximumTime: 5,
            capacity: GeometricConstraintCapacity(maximumBodies: 4, maximumPositions: 3, maximumVelocities: 3,
                maximumRows: 6, maximumMetadataBytes: 32768), work: &work)
    }

    @inline(never)
    static func rows(_ geometry: GeometricConstraintSystem, state: KinematicState) throws -> GeometricPhysicalRowWitness {
        var work = try MechanismProbeContext.work()
        let service: any HolonomicGeometryProviding = GeometricRelationEvaluator()
        let policy = try rowPolicy()
        let sample = try service.evaluate(geometry, state: state, policy: policy.evaluation, work: &work)
        return try service.physicalRows(geometry, state: state, supplied: sample, policy: policy, work: &work)
    }

    @inline(never)
    static func allocate(_ geometry: GeometricConstraintSystem, state: KinematicState,
        rows: GeometricPhysicalRowWitness) throws -> GeometricPhysicalAllocationWitness {
        var work = try MechanismProbeContext.work()
        let policy = try GeometricPhysicalAllocationPolicy(rows: rowPolicy(), rank: solvePolicy().constraints)
        let service: any GeometricPhysicalAllocationProviding = GeometricPhysicalAllocationEvaluator()
        let supplied = try service.physicalAllocation(geometry, state: state, supplied: rows, policy: policy, work: &work)
        return try GeometricPhysicalAllocationAcceptance.validated(supplied, system: geometry, state: state,
            policy: policy, work: &work)
    }

    @inline(never)
    static func assemble(_ fixture: PlanarLoopProbeModel, torque: Double = 1) throws -> PhysicalRigidDynamicsSystem {
        let model = fixture.model, state = model.descriptor.initialState
        let snapshot = try model.evaluate(model.makeState(state))
        var inertias: [PlanarRigidBodyInertia] = []
        for body in snapshot.tree.bodies {
            guard let source = model.descriptor.bodies.first(where: { $0.id == body.id }),
                  case .planar(let record) = source, let inertia = record.inertia else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            inertias.append(try PlanarRigidBodyInertia(body: record.id, frame: record.frame, properties: inertia.properties))
        }
        let applied = try BodyWrenchContribution(body: fixture.crank, frame: model.tree.worldFrame,
            referencePoint: .zero, wrench: SpatialWrench(torque: Vector3(0, 0, torque), force: .zero), channel: .applied)
        let input = try PlanarRigidDynamicsInput(snapshot: snapshot, velocity: state.v, inertias: inertias,
            gravity: nil, bodyWrenches: [applied])
        var work = try MechanismProbeContext.work(), loads = try loadWork()
        let service: any PhysicalRigidEquationComputing = RigidEquationKernel()
        return try service.assemble(PhysicalRigidDynamicsInput(planar: input), admission: MechanismProbeContext.admission(),
            loadWork: &loads, work: &work)
    }

    @inline(never)
    static func solve(_ dynamics: PhysicalRigidDynamicsSystem, rows: GeometricPhysicalRowWitness) throws -> PhysicalConstrainedMotion {
        var work = try MechanismProbeContext.work(), dynamic = try MechanismProbeContext.work()
        var rank = try MechanismProbeContext.work(), linear = try MechanismProbeContext.work()
        let service: any PhysicalConstrainedMechanismSolving = MassWeightedMechanismSolver(
            physicalDynamics: DenseRigidDynamics(physicalEquations: RigidEquationKernel()), physicalEquations: RigidEquationKernel())
        return try service.acceleration(dynamics, sample: rows.original.velocity, drive: [0, 0, 0], policy: solvePolicy(),
            work: &work, dynamicsWork: &dynamic, rankWork: &rank, linearWork: &linear)
    }

    @inline(never)
    func input(geometry: GeometricConstraintSystem? = nil, state: KinematicState? = nil,
        motion: PhysicalConstrainedMotion? = nil, allocation: GeometricPhysicalAllocationWitness? = nil,
        drive: [Double] = [0, 0, 0], topology: ClosedLoopReactionTopology = .completeTreeAndDeclaredRows) -> PlanarClosedLoopReactionInput {
        PlanarClosedLoopReactionInput(motion: motion ?? self.motion, geometry: geometry ?? self.geometry,
            state: state ?? fixture.model.descriptor.initialState, allocation: allocation ?? self.allocation,
            originalDrive: drive, topology: topology)
    }

    @inline(never)
    func recover(frame: EntityID? = nil) throws -> PlanarClosedLoopReactionReport {
        let input = self.input(), policy = try Self.policy()
        var work = try MechanismProbeContext.work(), loads = try Self.loadWork()
        let service: any PlanarClosedLoopReactionRecovering = PlanarClosedLoopReactionRecovery()
        return try service.recover(input, outputFrame: frame ?? fixture.model.tree.worldFrame, policy: policy,
            loadWork: &loads, work: &work)
    }

    static func loadWork() throws -> LoadWork { LoadWork(budget: try LoadBudget(maximumWork: 1000, maximumScalars: 1024)) }

    static func rowPolicy() throws -> GeometricPhysicalRowPolicy {
        try GeometricPhysicalRowPolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 3, maximumRows: 6,
            expectedLayoutRevision: 1), maximumBodies: 4, originalComparisonTolerance: 1e-10,
            projectionTolerance: NumericalTolerance(absolute: 1e-10, relative: 1e-10))
    }

    @inline(never)
    static func solvePolicy() throws -> MechanismSolvePolicy {
        let base = try MechanismProbeContext.policy()
        let constraints = try ConstraintSolvePolicy(evaluation: rowPolicy().evaluation, diagonalMetric: [1, 2, 3],
            energyScale: 7, rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10,
            originalResidualTolerance: 1e-9, maximumCorrection: 100, nonlinear: base.constraints.nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            linearTolerance: base.constraints.linearTolerance)
        let dynamics = try DynamicsSolvePolicy(capability: base.dynamics.capability,
            linearTolerance: base.dynamics.linearTolerance, coordinateScales: [2, 3, 4], energyScale: 7, timeScale: 2)
        return try MechanismSolvePolicy(dynamics: dynamics, constraints: constraints, maximumCoordinates: 3,
            maximumRows: 6, originalTolerance: 1e-9)
    }

    @inline(never)
    static func policy() throws -> ClosedLoopReactionPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-9, relative: 1e-10)
        let tree = try TreeReactionPolicy(maximumBodies: 4, maximumJoints: 3, maximumBodyLoads: 13,
            generalizedForceScales: [1, 1, 1], generalizedTolerance: tolerance,
            forceTolerance: tolerance, torqueTolerance: tolerance)
        let base = try MechanismProbeContext.admission()
        // One identified load plus two endpoint actions for each of the six original rows.
        let admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 4, maximumVelocities: 3,
            maximumBodyWrenches: 13, maximumGeneralizedContributions: 8),
            angularVelocityTolerance: base.angularVelocityTolerance, linearVelocityTolerance: base.linearVelocityTolerance)
        return try ClosedLoopReactionPolicy(maximumRows: 6, geometry: rowPolicy(), rank: solvePolicy().constraints,
            tree: tree, admission: admission, positionTolerance: 1e-9,
            velocityTolerance: 1e-9, accelerationTolerance: 1e-9)
    }
}
