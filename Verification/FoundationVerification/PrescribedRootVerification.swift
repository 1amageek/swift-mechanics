import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension FoundationVerification {
    @inline(never)
    static func verifyPrescribedRootMotion() throws {
        try checkPrescribedRootProfile(planar: false)
        try checkPrescribedRootProfile(planar: true)
        print("AF25 full prescribed-root original effort/power, root-only evolution and cold replay passed.")
    }

    @inline(never)
    private static func checkPrescribedRootProfile(planar: Bool) throws {
        let context = try PrescribedRootProbeContext(PrescribedRootProbeModel(planar: planar))
        try checkPrescribedRootForce(context, time: 0.7)
        try checkPrescribedRootWork(context)
        try checkPrescribedRootEvolution(context)
    }

    @inline(never)
    private static func checkPrescribedRootForce(_ context: PrescribedRootProbeContext, time: Double) throws {
        let state = try context.state(time: time), motion = try context.motion(time: time)
        let power = try context.power(motion)
        let expected = PrescribedRootProbeOracle(context.fixture, time: time)
        guard let binding = context.geometry.prescribedRoot else { throw FoundationVerificationError.analyticCheckFailed }
        try require(context.geometry.rowIDs.isEmpty && binding.dynamicCoordinates.isEmpty)
        try require(motion.motion.values == state.acceleration && motion.motion.sourceVelocity == state.v)
        try require(motion.motion.rowIDs == binding.rowIDs && motion.motion.rank.rank == state.v.count)
        try require(motion.motion.rank.reactionNullity == 0 && motion.motion.originalPhysicalResidual < 1e-9)
        try require(power.system === motion.system && power.knownCoordinates == binding.knownCoordinates)
        try require(power.rootActuationEffort.count == expected.effort.count)
        for i in expected.effort.indices {
            try require(abs(power.rootActuationEffort[i]-expected.effort[i]) < 1e-9)
            try require(abs(motion.motion.generalizedReaction[i]-expected.effort[i]) < 1e-9)
        }
        try require(abs(power.energy.kineticEnergy-expected.kineticEnergy) < 1e-9)
        try require(abs(power.rootActuationPower-expected.requiredPower) < 1e-9)
        try require(abs(power.knownCoordinatePower-expected.requiredPower) < 1e-9)
        try require(abs(power.energy.kineticEnergyRate-expected.requiredPower) < 1e-9)
        try require(abs(power.energy.requiredVirtualPower-expected.requiredPower) < 1e-9)
        try require(power.dynamicCoordinatePower == 0 && power.drivePower == 0 && power.knownLoadPower == 0)
        try require(power.geometricReactionPower == 0 && power.anchorPrescribedPower == 0)
        try require(power.energy.requiredPrescribedPower == 0)
    }

    @inline(never)
    private static func checkPrescribedRootWork(_ context: PrescribedRootProbeContext) throws {
        let end = 0.04, intervals = 4
        let h = end/Double(intervals)
        var integral = 0.0
        for i in 0...intervals {
            let weight = i == 0 || i == intervals ? 1.0 : (i % 2 == 0 ? 2.0 : 4.0)
            integral += weight*(try context.power(context.motion(time: Double(i)*h))).rootActuationPower
        }
        let initial = PrescribedRootProbeOracle(context.fixture, time: 0)
        let final = PrescribedRootProbeOracle(context.fixture, time: end)
        try require(abs(integral*h/3-(final.kineticEnergy-initial.kineticEnergy)) < 1e-8)
    }

    @inline(never)
    private static func checkPrescribedRootEvolution(_ context: PrescribedRootProbeContext) throws {
        let equation = try context.equation()
        let (session, continuation) = try context.session(equation)
        defer { _ = session.shutdown() }
        let codec = NativeRuntimeCheckpointCodec()
        _ = try PrescribedRootEndpointProbe(session: session, equation: equation, continuation: continuation, time: 0.02)
        let saved = try session.checkpoint(codec: codec)
        let final = try PrescribedRootEndpointProbe(session: session, equation: equation, continuation: continuation, time: 0.04)
        let expected = try context.state(time: 0.04)
        try require(final.accepted.checkpoint.physical.q == expected.q && final.accepted.checkpoint.physical.v == expected.v)
        try require(final.accepted.checkpoint.physical.acceleration == expected.acceleration)
        let finalBytes = try session.checkpoint(codec: codec)
        try restartPrescribedRoot(session, bytes: saved)
        let replay = try PrescribedRootEndpointProbe(session: session, equation: equation, continuation: continuation, time: 0.04)
        try require(replay.accepted == final.accepted)
        try require(try session.checkpoint(codec: codec) == finalBytes)
        try checkPrescribedRootFreshReplay(saved, final: final, bytes: finalBytes, planar: context.fixture.planar)
        try checkPrescribedRootForgedAcceleration(session)
    }

    @inline(never)
    private static func checkPrescribedRootFreshReplay(_ saved: [UInt8], final: PrescribedRootEndpointProbe,
                                                     bytes: [UInt8], planar: Bool) throws {
        let context = try PrescribedRootProbeContext(PrescribedRootProbeModel(planar: planar))
        let equation = try context.equation(), (session, continuation) = try context.session(equation)
        defer { _ = session.shutdown() }
        let codec = NativeRuntimeCheckpointCodec()
        try restartPrescribedRoot(session, bytes: saved)
        let replay = try PrescribedRootEndpointProbe(session: session, equation: equation, continuation: continuation, time: 0.04)
        try require(replay.accepted == final.accepted)
        try require(try session.checkpoint(codec: codec) == bytes)
    }

    @inline(never)
    private static func restartPrescribedRoot(_ session: PrescribedRootProbeContext.Session, bytes: [UInt8]) throws {
        _ = try session.restart(bytes, codec: NativeRuntimeCheckpointCodec())
    }

    @inline(never)
    private static func checkPrescribedRootForgedAcceleration(_ session: PrescribedRootProbeContext.Session) throws {
        let prefix = session.snapshot(), old = prefix.checkpoint, state = old.physical
        let codec = NativeRuntimeCheckpointCodec(), saved = try session.checkpoint(codec: codec)
        var acceleration = state.acceleration
        acceleration[0] += 0.1
        let forged = try KinematicState(revision: state.revision, time: state.time, q: state.q, v: state.v,
            acceleration: acceleration)
        let checkpoint = try RuntimeCheckpoint(model: old.model, continuation: old.continuation, physical: forged,
            contributors: old.contributors, random: old.random, acceptedSteps: old.acceptedSteps)
        let bytes = try codec.encode(checkpoint, capacity: session.configuration.capacity)
        var refused = false
        do throws(RuntimeFailure) { _ = try session.restart(bytes, codec: codec) }
        catch { try require(error.code == .invalidState); refused = true }
        try require(refused && session.snapshot() == prefix && (try session.checkpoint(codec: codec)) == saved)
    }
}
