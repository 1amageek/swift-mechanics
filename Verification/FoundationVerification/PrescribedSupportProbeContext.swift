import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class PrescribedSupportProbeContext: Sendable {
    let fixture: PrescribedSupportProbeModel
    let geometry: GeometricConstraintSystem
    let policy: PlanarPrescribedRootReactionPolicy

    @inline(never)
    init(_ fixture: PrescribedSupportProbeModel) throws {
        self.fixture = fixture
        var work = try GeometricProbeContext.work()
        geometry = try GeometricConstraintSystem(model: fixture.model, layout: fixture.layout, relations: [],
            minimumPosition: [Double](repeating: -10, count: fixture.model.tree.layout.positionCount),
            maximumPosition: [Double](repeating: 10, count: fixture.model.tree.layout.positionCount),
            minimumTime: 0, maximumTime: 2,
            capacity: GeometricConstraintCapacity(maximumBodies: 2, maximumPositions: 4, maximumVelocities: 4,
                maximumRows: 6, maximumMetadataBytes: 32768), work: &work, prescribedBase: fixture.base)
        policy = try Self.makePolicy(fixture.layout)
    }

    @inline(never)
    private static func makePolicy(_ layout: ConstraintCoordinateLayout) throws -> PlanarPrescribedRootReactionPolicy {
        let original = try MechanismProbeContext.policy()
        let n = layout.scales.count
        let evaluation = try ConstraintEvaluationPolicy(maximumCoordinates: 4, maximumRows: 6,
            expectedLayoutRevision: 1)
        let constraints = try ConstraintSolvePolicy(evaluation: evaluation, diagonalMetric: [Double](repeating: 1, count: n),
            energyScale: 7, rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10,
            originalResidualTolerance: 1e-9, maximumCorrection: 10, nonlinear: original.constraints.nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            linearTolerance: original.constraints.linearTolerance)
        let dynamics = try DynamicsSolvePolicy(capability: original.dynamics.capability,
            linearTolerance: original.dynamics.linearTolerance, coordinateScales: layout.scales,
            energyScale: 7, timeScale: layout.timeScale)
        let mechanism = try MechanismSolvePolicy(dynamics: dynamics, constraints: constraints,
            maximumCoordinates: 4, maximumRows: 6, originalTolerance: 1e-9)
        let tolerance = try NumericalTolerance(absolute: 1e-8, relative: 1e-8)
        let tree = try TreeReactionPolicy(maximumBodies: 2, maximumJoints: 1, maximumBodyLoads: 2,
            generalizedForceScales: [Double](repeating: 1, count: n), generalizedTolerance: tolerance,
            forceTolerance: tolerance, torqueTolerance: tolerance)
        return try PlanarPrescribedRootReactionPolicy(geometry: evaluation, mechanism: mechanism, tree: tree)
    }

    @inline(never)
    func input(time: Double, drive: [Double]? = nil) throws -> PlanarPrescribedRootReactionInput {
        guard let binding = geometry.prescribedRoot else { throw FoundationVerificationError.analyticCheckFailed }
        var work = try GeometricProbeContext.work()
        let base = try binding.sample(time: time, work: &work)
        let n = fixture.layout.scales.count
        var q = base.q, v = base.v, a = base.a
        while q.count < fixture.model.tree.layout.positionCount { q.append(0) }
        while v.count < n { v.append(0); a.append(0) }
        let state = try KinematicState(revision: 1, time: time, q: q, v: v, acceleration: a)
        let original = try GeometricRelationEvaluator().evaluate(geometry, state: state,
            policy: policy.geometry, work: &work)
        return try assemble(original, state: state, base: base, drive: drive)
    }

    @inline(never)
    private func assemble(_ original: HolonomicGeometrySample, state: KinematicState,
                          base: PrescribedBaseMotionSample, drive: [Double]?) throws -> PlanarPrescribedRootReactionInput {
        var inertias: [PlanarRigidBodyInertia] = []
        for body in original.snapshot.tree.bodies {
            guard let item = fixture.model.descriptor.bodies.first(where: { $0.id == body.id }),
                  case .planar(let record) = item, let inertia = record.inertia else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            inertias.append(try PlanarRigidBodyInertia(body: record.id, frame: record.frame, properties: inertia.properties))
        }
        let input = try PhysicalRigidDynamicsInput(planar: PlanarRigidDynamicsInput(snapshot: original.snapshot,
            velocity: state.v, inertias: inertias, gravity: nil))
        var work = try GeometricProbeContext.work()
        var load = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 100))
        let system = try RigidEquationKernel().assemble(input, admission: PlanarPhysicalProbeContext.admission(),
            loadWork: &load, work: &work)
        return try solve(system, original: original, state: state, base: base, drive: drive)
    }

    @inline(never)
    private func solve(_ system: PhysicalRigidDynamicsSystem, original: HolonomicGeometrySample,
                       state: KinematicState, base: PrescribedBaseMotionSample,
                       drive: [Double]?) throws -> PlanarPrescribedRootReactionInput {
        guard let binding = geometry.prescribedRoot else { throw FoundationVerificationError.analyticCheckFailed }
        var work = try GeometricProbeContext.work()
        let constraint = try PrescribedRootConstraint(system: system, geometry: original.velocity, base: base,
            rowIDs: binding.rowIDs, policy: policy.mechanism, work: &work)
        var dynamics = try GeometricProbeContext.work(), rank = try GeometricProbeContext.work()
        var linear = try GeometricProbeContext.work()
        let zero = [Double](repeating: 0, count: fixture.layout.scales.count)
        let solver: any PrescribedRootMechanismSolving = MassWeightedMechanismSolver(
            physicalDynamics: DenseRigidDynamics(physicalEquations: RigidEquationKernel()), physicalEquations: RigidEquationKernel())
        let motion = try solver.acceleration(constraint, drive: zero, policy: policy.mechanism, work: &work,
            dynamicsWork: &dynamics, rankWork: &rank, linearWork: &linear)
        return PlanarPrescribedRootReactionInput(motion: motion, geometry: geometry, state: state,
            constraint: constraint, originalDrive: drive ?? zero, topology: .completeTree)
    }

    @inline(never)
    func recover(_ input: PlanarPrescribedRootReactionInput, frame: EntityID? = nil) throws -> PlanarPrescribedRootReactionReport {
        var work = try GeometricProbeContext.work()
        var load = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 100))
        let service: any PlanarPrescribedRootReactionRecovering = PlanarPrescribedRootReactionRecovery()
        return try service.recover(input, outputFrame: frame ?? fixture.model.descriptor.worldFrame,
            policy: policy, loadWork: &load, work: &work)
    }
}
