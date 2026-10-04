import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension FoundationVerification {
    @inline(never)
    static func verifyPrescribedRotorEvolution() throws {
        try checkPrescribedRotorProfile(planar: false)
        try checkPrescribedRotorProfile(planar: true)
        print("AF25 prescribed-root dynamic descendants, partitioned power and cold force/replay passed.")
    }

    @inline(never)
    private static func checkPrescribedRotorProfile(planar: Bool) throws {
        let context = try PrescribedRotorProbeContext(PrescribedRotorProbeModel(planar: planar))
        let equation = try context.equation()
        let (session, continuation) = try context.session(equation: equation)
        defer { _ = session.shutdown() }
        try checkPrescribedRotorPower(session, context: context, equation: equation)
        let codec = NativeRuntimeCheckpointCodec()
        _ = try PrescribedRootEndpointProbe(session: session, equation: equation, continuation: continuation, time: 0.02)
        let saved = try session.checkpoint(codec: codec)
        let final = try PrescribedRootEndpointProbe(session: session, equation: equation, continuation: continuation, time: 0.04)
        try checkPrescribedRotorState(final.accepted.checkpoint.physical, context: context)
        try checkPrescribedRotorPower(session, context: context, equation: equation)
        let bytes = try session.checkpoint(codec: codec)
        try restartPrescribedRotor(session, bytes: saved)
        let replay = try PrescribedRootEndpointProbe(session: session, equation: equation, continuation: continuation, time: 0.04)
        try require(replay.accepted == final.accepted)
        try require(try session.checkpoint(codec: codec) == bytes)
        try checkPrescribedRotorFreshReplay(saved, final: final, bytes: bytes, planar: planar)
        try checkPrescribedRotorColdForce(session, fixture: context.fixture)
    }

    @inline(never)
    private static func checkPrescribedRotorState(_ state: KinematicState, context: PrescribedRotorProbeContext) throws {
        let t = state.time, phi = 0.25+0.4*t-0.05*t*t, speed = 0.4-0.1*t
        let original = try context.state(time: t, relativePosition: phi, relativeVelocity: speed, relativeAcceleration: -0.1)
        let k = context.fixture.model.tree.rootBase.velocityCount
        let p = context.fixture.model.tree.rootBase.positionCount
        try require(Array(state.q[..<p]) == Array(original.q[..<p]))
        try require(Array(state.v[..<k]) == Array(original.v[..<k]))
        try require(Array(state.acceleration[..<k]) == Array(original.acceleration[..<k]))
        for i in [context.fixture.firstPosition, context.fixture.secondPosition] {
            try require(abs(state.q[i]-phi) < 1e-9)
        }
        for i in [context.fixture.firstVelocity, context.fixture.secondVelocity] {
            try require(abs(state.v[i]-speed) < 1e-9 && abs(state.acceleration[i]+0.1) < 1e-9)
        }
    }

    @inline(never)
    private static func checkPrescribedRotorPower(_ session: PrescribedRotorProbeContext.Session,
                                                context: PrescribedRotorProbeContext,
                                                equation: GeometricMechanismEquation) throws {
        let prefix = session.snapshot(), fixture = context.fixture
        let k = fixture.model.tree.rootBase.velocityCount
        let budget = equation.publicationBudget
        _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            var work = NumericalWork(budget: budget)
            var point = [Double](repeating: 0, count: equation.descriptor.dimensions.count)
            try equation.read(trial, into: &point)
            let proof = try equation.consistent(time: trial.timeSeconds, point: point, work: &work, control: control)
            let t = trial.timeSeconds, omega = 0.2+0.3*t, relativeSpeed = 0.4-0.1*t
            let vx = 0.4+0.3*t, vy = -0.2+0.2*t
            let energy = 1.5*(vx*vx+vy*vy)+omega*omega+2.5*(omega+relativeSpeed)*(omega+relativeSpeed)
            let rootPower = 0.9*vx+0.6*vy+1.6*omega
            let energyRate = rootPower+relativeSpeed
            guard let power = proof.partitionedPower, let original = proof.mechanicalEnergy,
                  power.rootActuationEffort.count == k, proof.acceleration.rank.rank == k+1,
                  proof.acceleration.rank.reactionNullity == 1, proof.acceleration.rowIDs.count == k+2,
                  abs(proof.acceleration.values[fixture.firstVelocity]+0.1) < 1e-9,
                  abs(proof.acceleration.values[fixture.secondVelocity]+0.1) < 1e-9,
                  abs(power.rootActuationEffort[0]-0.9) < 1e-9,
                  abs(power.rootActuationEffort[1]-0.6) < 1e-9,
                  abs(power.rootActuationEffort[k-1]-1.6) < 1e-9,
                  abs(power.energy.kineticEnergy-energy) < 1e-9,
                  abs(power.rootActuationPower-rootPower) < 1e-9,
                  abs(power.drivePower-relativeSpeed) < 1e-9,
                  abs(power.dynamicCoordinatePower-relativeSpeed) < 1e-9,
                  abs(power.knownCoordinatePower-rootPower) < 1e-9,
                  abs(power.geometricReactionPower) < 1e-9,
                  abs(original.kineticEnergyRate-energyRate) < 1e-9,
                  abs(original.requiredVirtualPower-energyRate) < 1e-9,
                  original.requiredPrescribedPower == 0, power.anchorPrescribedPower == 0,
                  power.knownLoadPower == 0 else {
                throw RuntimeFailure(.invalidState, message: "Independent prescribed rotor force/power balance failed.")
            }
            return .reject
        }
        try require(session.snapshot() == prefix)
    }

    @inline(never)
    private static func checkPrescribedRotorFreshReplay(_ saved: [UInt8], final: PrescribedRootEndpointProbe,
                                                      bytes: [UInt8], planar: Bool) throws {
        let context = try PrescribedRotorProbeContext(PrescribedRotorProbeModel(planar: planar))
        let equation = try context.equation(), (session, continuation) = try context.session(equation: equation)
        defer { _ = session.shutdown() }
        let codec = NativeRuntimeCheckpointCodec()
        try restartPrescribedRotor(session, bytes: saved)
        let replay = try PrescribedRootEndpointProbe(session: session, equation: equation, continuation: continuation, time: 0.04)
        try require(replay.accepted == final.accepted)
        try require(try session.checkpoint(codec: codec) == bytes)
    }

    @inline(never)
    private static func restartPrescribedRotor(_ session: PrescribedRotorProbeContext.Session, bytes: [UInt8]) throws {
        _ = try session.restart(bytes, codec: NativeRuntimeCheckpointCodec())
    }

    @inline(never)
    private static func checkPrescribedRotorColdForce(_ session: PrescribedRotorProbeContext.Session,
                                                    fixture: PrescribedRotorProbeModel) throws {
        let prefix = session.snapshot(), old = prefix.checkpoint, state = old.physical
        var a = state.acceleration
        a[fixture.firstVelocity] += 0.2; a[fixture.secondVelocity] += 0.2
        let forged = try KinematicState(revision: state.revision, time: state.time, q: state.q, v: state.v, acceleration: a)
        let checkpoint = try RuntimeCheckpoint(model: old.model, continuation: old.continuation, physical: forged,
            contributors: old.contributors, random: old.random, acceptedSteps: old.acceptedSteps)
        let codec = NativeRuntimeCheckpointCodec(), saved = try session.checkpoint(codec: codec)
        let bytes = try codec.encode(checkpoint, capacity: session.configuration.capacity)
        var refused = false
        do throws(RuntimeFailure) { _ = try session.restart(bytes, codec: codec) }
        catch { try require(error.code == .invalidState); refused = true }
        try require(refused && session.snapshot() == prefix && (try session.checkpoint(codec: codec)) == saved)
    }
}
