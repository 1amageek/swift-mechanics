import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifyMovingBaseEvolution() throws {
        let fixture = try MovingBaseProbeModel(), equation = try MovingBaseProbeContext.equation(fixture)
        let (first, provider) = try MovingBaseProbeContext.session(fixture, equation: equation)
        defer { _ = first.shutdown() }
        let service: any ProjectedMechanismEvolving = ProjectedNonlinearMechanismEvolution()
        let initial = try first.checkpoint(codec: NativeRuntimeCheckpointCodec())
        let result = try service.advance(first, equations: equation, continuation: provider, to: 0.1)
        try checkMovingBase(fixture, state: result.accepted.checkpoint.physical)
        try checkMovingBasePower(first, equation: equation)
        let saved = try first.checkpoint(codec: NativeRuntimeCheckpointCodec())
        try checkMovingBaseRestoreRefusals(first)
        let coldFixture = try MovingBaseProbeModel(), coldEquation = try MovingBaseProbeContext.equation(coldFixture)
        let (cold, coldProvider) = try MovingBaseProbeContext.session(coldFixture, equation: coldEquation)
        defer { _ = cold.shutdown() }
        _ = try cold.restart(saved, codec: NativeRuntimeCheckpointCodec())
        try require(try cold.checkpoint(codec: NativeRuntimeCheckpointCodec()) == saved)
        _ = try service.advance(first, equations: equation, continuation: provider, to: 0.2)
        _ = try service.advance(cold, equations: coldEquation, continuation: coldProvider, to: 0.2)
        try require(try first.checkpoint(codec: NativeRuntimeCheckpointCodec()) == cold.checkpoint(codec: NativeRuntimeCheckpointCodec()))
        try checkMovingBase(fixture, state: first.snapshot().checkpoint.physical)
        try checkMovingBasePower(first, equation: equation)
        _ = try first.restart(initial, codec: NativeRuntimeCheckpointCodec())
        _ = try service.advance(first, equations: equation, continuation: provider, to: 0.1)
        try require(try first.checkpoint(codec: NativeRuntimeCheckpointCodec()) == saved)
        print("AF23 moving base: regular axis coupling, original physical points/q/v/a/power and cold replay passed")
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkMovingBaseRestoreRefusals(_ session: MovingBaseProbeContext.Session) throws {
        let codec = NativeRuntimeCheckpointCodec(), source = session.snapshot().checkpoint
        let saved = try session.checkpoint(codec: codec), physical = source.physical
        let badAcceleration = try KinematicState(revision: physical.revision, time: physical.time, q: physical.q, v: physical.v,
            acceleration: physical.acceleration.map { $0 + 0.1 }, prescribedAnchors: physical.prescribedAnchors)
        let sample = physical.prescribedAnchors[0], motion = sample.motion
        let badSample = try PrescribedAnchorState(frame: sample.frame, time: sample.time,
            motion: FrameMotion(pose: motion.pose,
                velocity: SpatialMotion(angular: Vector3(motion.velocity.angular.x, motion.velocity.angular.y, motion.velocity.angular.z + 0.1),
                    linear: motion.velocity.linear), acceleration: motion.acceleration))
        let badLaw = try KinematicState(revision: physical.revision, time: physical.time, q: physical.q, v: physical.v,
            acceleration: physical.acceleration, prescribedAnchors: [badSample])
        for candidate in [badAcceleration, badLaw] {
            let checkpoint = try RuntimeCheckpoint(model: source.model, continuation: source.continuation, physical: candidate,
                contributors: source.contributors, random: source.random, acceptedSteps: source.acceptedSteps)
            let encoded = try codec.encode(checkpoint, capacity: session.configuration.capacity)
            var refused = false
            do throws(RuntimeFailure) { _ = try session.restart(encoded, codec: codec) }
            catch { try require(error.code == .invalidState); refused = true }
            try require(refused && (try session.checkpoint(codec: codec)) == saved)
        }
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkMovingBasePower(_ session: MovingBaseProbeContext.Session, equation: GeometricMechanismEquation) throws {
        let codec = NativeRuntimeCheckpointCodec(), prefix = try session.checkpoint(codec: codec)
        let budget = try MechanismProbeContext.work().budget
        _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 1)
            var work = NumericalWork(budget: budget)
            var point = [Double](repeating: 0, count: 4)
            try equation.read(trial, into: &point)
            let proof = try equation.consistent(time: trial.timeSeconds, point: point, work: &work, control: control)
            guard let energy = proof.mechanicalEnergy, proof.acceleration.generalizedReaction.count == 2,
                  proof.acceleration.rank.rank == 1 else {
                throw RuntimeFailure(.invalidState, message: "Moving-base public physical proof is absent.")
            }
            let time = trial.timeSeconds, vx = 0.3 + 0.2 * time, vy = 0.4 - 0.1 * time
            let omega = 0.3 + 0.2 * time, v = 0.1 + 0.3 * time
            let prescribed = 3 * (vx * 0.2 - vy * 0.1) + 1.2 * omega
            let expectedK = 1.5 * (vx * vx + vy * vy) + 0.5 * omega * omega + (omega + v) * (omega + v)
            guard abs(proof.acceleration.generalizedReaction[0] + 0.5) < 1e-8,
                  abs(proof.acceleration.generalizedReaction[1] - 0.5) < 1e-8,
                  abs(energy.kineticEnergy - expectedK) < 1e-8,
                  abs(energy.requiredVirtualPower - v) < 1e-8,
                  abs(energy.requiredPrescribedPower - prescribed) < 1e-8,
                  abs(energy.kineticEnergyRate - v - prescribed) < 1e-8 else {
                throw RuntimeFailure(.invalidState, message: "Moving-base public original reaction or power differs.")
            }
            return .reject
        }
        try require(try session.checkpoint(codec: codec) == prefix)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkMovingBase(_ fixture: MovingBaseProbeModel, state: KinematicState) throws {
        let time = state.time, expectedQ = 0.3 + 0.1 * time + 0.15 * time * time, expectedV = 0.1 + 0.3 * time
        for index in state.q.indices {
            try require(abs(state.q[index] - expectedQ) < 1e-8 && abs(state.v[index] - expectedV) < 1e-8)
            try require(abs(state.acceleration[index] - 0.3) < 1e-8)
        }
        try require(state.prescribedAnchors.count == 1 && state.prescribedAnchors[0].time == time)
        let snapshot = try fixture.model.evaluate(fixture.model.makeState(state))
        let a = try snapshot.body(EntityID(kind: .body, key: "moving-first")).motion
        let b = try snapshot.body(EntityID(kind: .body, key: "moving-second")).motion
        let pa = try a.pose.transforming(point: .unitX), pb = try b.pose.transforming(point: .unitX)
        try require(abs(pa.x - pb.x) < 1e-8 && abs(pa.y - pb.y) < 1e-8 && abs(pa.z - pb.z) < 1e-8)
        let ra = try a.pose.transforming(direction: .unitX), rb = try b.pose.transforming(direction: .unitX)
        let va = try a.velocity.linear.adding(a.velocity.angular.cross(ra))
        let vb = try b.velocity.linear.adding(b.velocity.angular.cross(rb))
        let aa = try a.acceleration.linear.adding(a.acceleration.angular.cross(ra)).adding(a.velocity.angular.cross(a.velocity.angular.cross(ra)))
        let ab = try b.acceleration.linear.adding(b.acceleration.angular.cross(rb)).adding(b.velocity.angular.cross(b.velocity.angular.cross(rb)))
        try require(abs(va.x - vb.x) < 1e-8 && abs(va.y - vb.y) < 1e-8 && abs(va.z - vb.z) < 1e-8)
        try require(abs(aa.x - ab.x) < 1e-8 && abs(aa.y - ab.y) < 1e-8 && abs(aa.z - ab.z) < 1e-8)
        let vx = 0.3 + 0.2 * time, vy = 0.4 - 0.1 * time, omega = 0.3 + 0.2 * time
        try require(abs(a.velocity.angular.z - (omega + expectedV)) < 1e-8)
        try require(abs(a.acceleration.angular.z - 0.5) < 1e-8)
        var actualK = 0.0
        for key in ["moving-base", "moving-first", "moving-second"] {
            let motion = try snapshot.body(EntityID(kind: .body, key: key)).motion
            actualK += 0.5 * (try motion.velocity.linear.dot(motion.velocity.linear))
            actualK += 0.5 * (try motion.velocity.angular.dot(motion.velocity.angular))
        }
        let expectedK = 1.5 * (vx * vx + vy * vy) + 0.5 * omega * omega + (omega + expectedV) * (omega + expectedV)
        try require(abs(actualK - expectedK) < 1e-8)
        let initialK = 1.5 * 0.25 + 0.5 * 0.09 + 0.16
        let driveWork = expectedQ - 0.3
        let prescribedWork = 1.5 * (vx * vx + vy * vy - 0.25) + 1.2 * (0.3 * time + 0.1 * time * time)
        try require(abs(actualK - initialK - driveWork - prescribedWork) < 1e-8)
    }
}
