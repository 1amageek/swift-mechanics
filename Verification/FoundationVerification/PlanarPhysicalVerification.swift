import SwiftMechanics
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("The verification profile must provide system scalar mathematics.")
#endif

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyPlanarPhysicalLower() throws {
        try checkPlanarFreeBody()
        try checkPlanarPhysicalRows()
        print("Planar physical lower verification passed: original 2D source, M/bias/solve/K/P/L/work, geometric covectors and typed refusals.")
    }

    @inline(never)
    private static func checkPlanarFreeBody() throws {
        let model = try PlanarPhysicalProbeModel.freeBody()
        let input = try PlanarPhysicalProbeContext.input(model)
        let system = try PlanarPhysicalProbeContext.assemble(input)
        try checkPlanarMassAndSolve(system)
        try checkPlanarOriginalEnergy(system)
        try checkPlanarSourceRefusals(input, system: system)
    }

    @inline(never)
    private static func checkPlanarMassAndSolve(_ system: PhysicalRigidDynamicsSystem) throws {
        let rx = 0.5*cos(0.3)-0.25*sin(0.3), ry = 0.5*sin(0.3)+0.25*cos(0.3)
        let expected = [2, 0, -2*ry, 0, 2, 2*rx, -2*ry, 2*rx, 1+2*(rx*rx+ry*ry)]
        for i in expected.indices { try require(abs(system.massMatrix[i]-expected[i]) < 1e-10) }
        try require(abs(system.inertialBias[0]+0.72*rx) < 1e-10 && abs(system.inertialBias[1]+0.72*ry) < 1e-10)
        try require(abs(system.inertialBias[2]) < 1e-10 && abs(system.forces.gravity[2]+20*rx) < 1e-10)
        var work = try PlanarPhysicalProbeContext.work()
        let solver: any PhysicalRigidDynamicsSolving = DenseRigidDynamics(physicalEquations: RigidEquationKernel())
        let result = try solver.forward(system, driveForce: [0, 0, 0], policy: PlanarPhysicalProbeContext.solvePolicy(), work: &work)
        let acceleration = [0.36*rx, -10+0.36*ry, 0]
        for i in acceleration.indices { try require(abs(result.acceleration[i]-acceleration[i]) < 1e-9) }
        try require(result.system === system && result.originalPhysicalResidual.isAccepted && work.operations > 0)
        let inverse = try solver.inverse(system, acceleration: acceleration, policy: PlanarPhysicalProbeContext.solvePolicy(), work: &work)
        for force in inverse.driveForce { try require(abs(force) < 1e-9) }
        guard case .planar(let source) = result.system.input.source else { throw FoundationVerificationError.analyticCheckFailed }
        try require(source.velocity == [0.4, -0.1, 0.6])
        try require(source.snapshot.bodies[0].motion.acceleration.linear.x == 9 && source.snapshot.bodies[0].motion.acceleration.linear.y == 8)
        try require(source.snapshot.bodies[0].motion.acceleration.angular.z == 7)
        try require(source.inertias.count == 1 && source.inertias[0].properties.mass == 2 && source.inertias[0].properties.polarInertiaAtCenter == 1)
    }

    @inline(never)
    private static func checkPlanarOriginalEnergy(_ system: PhysicalRigidDynamicsSystem) throws {
        let rx = 0.5*cos(0.3)-0.25*sin(0.3), ry = 0.5*sin(0.3)+0.25*cos(0.3)
        let acceleration = [0.36*rx, -10+0.36*ry, 0]
        let vx = 0.4-0.6*ry, vy = -0.1+0.6*rx
        var work = try PlanarPhysicalProbeContext.work()
        let equations: any PhysicalRigidEquationComputing = RigidEquationKernel()
        let required = try equations.inertialWrench(system, body: PlanarPhysicalProbeModel.id(.body, "free"),
            acceleration: acceleration, referencePointWorld: Vector3(1, 0.7, 0), work: &work)
        try require(abs(required.wrench.force.x) < 1e-10 && abs(required.wrench.force.y+20) < 1e-10)
        try require(abs(required.wrench.torque.z+20*rx) < 1e-10)
        let energy = try equations.energy(system, acceleration: acceleration, angularMomentumReference: .zero, requireComplete: true, work: &work)
        try require(abs(energy.kineticEnergy-(vx*vx+vy*vy+0.18)) < 1e-10)
        try require(abs(energy.linearMomentum.x-2*vx) < 1e-10 && abs(energy.linearMomentum.y-2*vy) < 1e-10)
        try require(abs(energy.angularMomentum.z-(0.6+(1+rx)*2*vy-(0.7+ry)*2*vx)) < 1e-10)
        guard let potential = energy.potentialEnergy else { throw FoundationVerificationError.analyticCheckFailed }
        try require(abs(potential-20*(0.7+ry)) < 1e-10 && abs(energy.kineticEnergyRate+20*vy) < 1e-10)
        try require(abs(energy.requiredVirtualPower-energy.kineticEnergyRate) < 1e-10 && energy.requiredPrescribedPower == 0)
    }

    @inline(never)
    private static func checkPlanarSourceRefusals(_ input: PlanarRigidDynamicsInput, system: PhysicalRigidDynamicsSystem) throws {
        var spatialRejected = false, velocityRejected = false, planeRejected = false, cancelled = false
        do { _ = try system.spatialSystem() }
        catch let error as DynamicsError { try require(error == .unsupportedDomain); spatialRejected = true }
        let equations: any PhysicalRigidEquationComputing = RigidEquationKernel()
        var work = try PlanarPhysicalProbeContext.work()
        var loads = LoadWork(budget: try LoadBudget(maximumWork: 10000, maximumScalars: 1024))
        let wrongVelocity = try PlanarRigidDynamicsInput(snapshot: input.snapshot, velocity: [0.4, -0.1, 0.7], inertias: input.inertias, gravity: input.gravity)
        do { _ = try equations.assemble(PhysicalRigidDynamicsInput(planar: wrongVelocity), admission: PlanarPhysicalProbeContext.admission(), loadWork: &loads, work: &work) }
        catch let error as DynamicsError { try require(error == .velocityMismatch); velocityRejected = true }
        let wrench = try BodyWrenchContribution(body: input.inertias[0].body, frame: input.snapshot.tree.worldFrame,
            referencePoint: Vector3(1, 0.7, 0), wrench: SpatialWrench(torque: .zero, force: .unitZ), channel: .applied)
        let wrongPlane = try PlanarRigidDynamicsInput(snapshot: input.snapshot, velocity: input.velocity, inertias: input.inertias, gravity: input.gravity, bodyWrenches: [wrench])
        do { _ = try equations.assemble(PhysicalRigidDynamicsInput(planar: wrongPlane), admission: PlanarPhysicalProbeContext.admission(), loadWork: &loads, work: &work) }
        catch let error as DynamicsError { try require(error == .nonplanarInput); planeRejected = true }
        var cancelledWork = try PlanarPhysicalProbeContext.work()
        do { _ = try equations.assemble(system.input, admission: PlanarPhysicalProbeContext.admission(cancelled: true), loadWork: &loads, work: &cancelledWork) }
        catch let error as DynamicsError { try require(error == .cancelled); cancelled = true }
        try require(spatialRejected && velocityRejected && planeRejected && cancelled && cancelledWork.operations == 0)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkPlanarPhysicalRows() throws {
        let model = try PlanarPhysicalProbeModel.sliders()
        try checkPlanarRowScale(model, scale: 4, multiplier: 48)
        try checkPlanarRowScale(model, scale: 2, multiplier: 12)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkPlanarRowScale(_ model: CompiledMechanicalModel, scale: Double, multiplier: Double) throws {
        let system = try PlanarPhysicalProbeContext.geometry(model, scale: scale)
        let state = model.descriptor.initialState
        let policy = try PlanarPhysicalProbeContext.geometryPolicy()
        let evaluator: any HolonomicGeometryProviding = GeometricRelationEvaluator()
        var work = try PlanarPhysicalProbeContext.work()
        let sample = try evaluator.evaluate(system, state: state, policy: policy.evaluation, work: &work)
        try checkPlanarOriginalRank(sample.velocity)
        let witness = try evaluator.physicalRows(system, state: state, supplied: sample, policy: policy, work: &work)
        let original = try GeometricPhysicalRowAcceptance.validated(witness, system: system, state: state, policy: policy, work: &work)
        try require(original.dimension == .planar && original.rows.count == 1 && sample.values == [0] && original.original.velocity.rowIDs == [91])
        let row = original.rows[0], gradient = 2/(scale*scale)
        try require(abs(row.first.linearGradient.x+gradient) < 1e-12 && abs(row.second.linearGradient.x-gradient) < 1e-12)
        try require(row.first.angularGradient == .zero && row.second.angularGradient == .zero && !row.isStructuralZero)
        try require(abs(sample.velocity.rows[0]+2*gradient) < 1e-12 && abs(sample.velocity.rows[1]-3*gradient) < 1e-12)
        let first = try row.first.linearGradient.scaled(by: multiplier), second = try row.second.linearGradient.scaled(by: multiplier)
        try require(abs(first.x+6) < 1e-12 && abs(second.x-6) < 1e-12 && first.y == 0 && second.y == 0)
        try require(try first.adding(second).magnitude() < 1e-12)
        let moment = try row.first.referencePointWorld.cross(first).adding(row.second.referencePointWorld.cross(second))
        try require(try moment.magnitude() < 1e-12 && row.first.referencePointWorld.x == 0 && row.second.referencePointWorld.x == 2)
        try require(system.metadata.hasPrefix("body-frame-planar-holonomic-v4") && work.operations > 0)
        var stale = false
        let changed = try KinematicState(revision: 1, time: 0.1, q: state.q, v: state.v, acceleration: state.acceleration)
        do { _ = try GeometricPhysicalRowAcceptance.validated(witness, system: system, state: changed, policy: policy, work: &work) }
        catch let error as GeometricConstraintError {
            guard case .staleSource = error else { throw FoundationVerificationError.unexpectedFailure }
            stale = true
        }
        try require(stale)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkPlanarOriginalRank(_ sample: VelocityConstraintSample) throws {
        var work = try PlanarPhysicalProbeContext.work()
        let assembler: any ConstraintRankAnalyzing = WeightedConstraintAssembler()
        let rank = try assembler.rank(sample, policy: MechanismProbeContext.policy().constraints, work: &work)
        try require(rank.rank == 1 && rank.reactionNullity == 0)
    }
}
