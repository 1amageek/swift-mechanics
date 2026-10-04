import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension FoundationVerification {
    @inline(never)
    static func verifyTrajectoryEvolution() throws {
        for planar in [true, false] {
            for piecewise in [true, false] {
                print("AF26 public trajectory profile: planar=\(planar), piecewise=\(piecewise).")
                let context = try TrajectoryEvolutionProbeContext(TrajectoryEvolutionProbeModel(
                    planar: planar, piecewise: piecewise))
                try checkTrajectoryOriginalPhysics(context, time: 0.7)
                try checkTrajectoryOriginalPhysics(context, time: 1)
                try checkTrajectoryRootWork(context)
                try checkTrajectoryReplay(context)
                let child = try TrajectoryEvolutionProbeContext(TrajectoryEvolutionProbeModel(
                    planar: planar, piecewise: piecewise, descendant: true, descendantDrive: 0.4))
                try checkTrajectoryOriginalPhysics(child, time: 0.7, q: 0.3, v: -0.2)
                try checkTrajectoryChildEvolution(child)
            }
            try checkTrajectoryKnotAndLaw(planar: planar)
        }
        print("AF26 public trajectory original body force/energy, descendant dynamics, exact knot and cold replay passed.")
    }

    @inline(never)
    private static func checkTrajectoryOriginalPhysics(_ context: TrajectoryEvolutionProbeContext,
                                                      time: Double, q: Double = 0, v: Double = 0) throws {
        let state = try context.state(time: time, relativePosition: q, relativeVelocity: v)
        let motion = try context.motion(state), power = try context.power(motion)
        let oracle = try TrajectoryEvolutionProbeOracle(context.fixture, time: time,
            relativePosition: q, relativeVelocity: v)
        guard let binding = context.geometry.rootBinding else { throw FoundationVerificationError.analyticCheckFailed }
        try require(context.geometry.rowIDs.isEmpty && motion.motion.sourceVelocity == state.v)
        try require(motion.motion.rowIDs == binding.rowIDs && motion.motion.originalPhysicalResidual < 1e-9)
        try require(power.system === motion.system && power.knownCoordinates == binding.knownCoordinates)
        try checkTrajectoryArray(Array(state.q.prefix(oracle.q.count)), oracle.q)
        try checkTrajectoryArray(Array(state.v.prefix(oracle.v.count)), oracle.v)
        try checkTrajectoryArray(Array(motion.motion.values.prefix(oracle.baseAcceleration.count)), oracle.baseAcceleration)
        try checkTrajectoryArray(power.rootActuationEffort, oracle.rootEffort)
        if let expected = oracle.dynamicAcceleration {
            try require(abs(motion.motion.values[oracle.v.count] - expected) < 1e-9)
            try require(binding.dynamicCoordinates.count == 1)
        } else {
            try require(binding.dynamicCoordinates.isEmpty)
        }
        try checkTrajectoryEnergy(power, oracle)
    }

    private static func checkTrajectoryArray(_ actual: [Double], _ expected: [Double]) throws {
        try require(actual.count == expected.count)
        for i in expected.indices { try require(abs(actual[i] - expected[i]) < 1e-9) }
    }

    private static func checkTrajectoryEnergy(_ power: PartitionedMechanicalPower,
                                             _ oracle: TrajectoryEvolutionProbeOracle) throws {
        try require(abs(power.energy.kineticEnergy - oracle.kineticEnergy) < 1e-9)
        try require(abs(power.energy.kineticEnergyRate - oracle.kineticEnergyRate) < 1e-9)
        try require(abs(power.rootActuationPower - oracle.rootPower) < 1e-9)
        try require(abs(power.drivePower - oracle.drivePower) < 1e-9)
        try require(abs(power.rootActuationPower + power.drivePower - power.energy.kineticEnergyRate) < 1e-9)
        // Fixed-anchor drift is zero analytically; body transport subtraction retains floating-point roundoff.
        try require(abs(power.geometricReactionPower) < 1e-9 && abs(power.anchorPrescribedPower) < 1e-9)
        try require(power.knownLoadPower == 0)
    }

    @inline(never)
    private static func checkTrajectoryRootWork(_ context: TrajectoryEvolutionProbeContext) throws {
        let end = 0.04, intervals = 4, h = end / Double(intervals)
        var integral = 0.0
        for i in 0...intervals {
            let weight = i == 0 || i == intervals ? 1.0 : (i % 2 == 0 ? 2.0 : 4.0)
            integral += weight * (try context.power(context.motion(context.state(time: Double(i) * h)))).rootActuationPower
        }
        let first = try TrajectoryEvolutionProbeOracle(context.fixture, time: 0)
        let last = try TrajectoryEvolutionProbeOracle(context.fixture, time: end)
        try require(abs(integral * h / 3 - (last.kineticEnergy - first.kineticEnergy)) < 1e-8)
    }

    @inline(never)
    private static func checkTrajectoryReplay(_ context: TrajectoryEvolutionProbeContext) throws {
        let session = try context.session()
        defer { _ = session.shutdown() }
        _ = try context.advance(session, to: 0.02)
        let saved = try context.checkpoint(session)
        let final = try context.advance(session, to: 0.04)
        let expected = try context.state(time: 0.04), state = final.accepted.checkpoint.physical
        try require(final.reachedRequestedTime && state.q == expected.q && state.v == expected.v)
        try require(state.acceleration == expected.acceleration)
        let history = try context.history(session)
        try require(history.acceptedTime.bitPattern == state.time.bitPattern && history.acceptedPoint == state.q + state.v)
        let bytes = try context.checkpoint(session)
        _ = try context.restore(session, bytes: saved)
        try require(try context.advance(session, to: 0.04).accepted == final.accepted)
        try require(try context.checkpoint(session) == bytes)
        try checkTrajectoryFreshReplay(context, saved: saved, final: final.accepted, bytes: bytes, time: 0.04)
        try checkTrajectoryForgedAcceleration(context, session: session)
    }

    @inline(never)
    private static func checkTrajectoryFreshReplay(_ original: TrajectoryEvolutionProbeContext, saved: [UInt8],
                                                 final: RuntimeAcceptedState, bytes: [UInt8], time: Double) throws {
        let context = try original.fresh(), session = try context.session()
        defer { _ = session.shutdown() }
        _ = try context.restore(session, bytes: saved)
        try require(try context.advance(session, to: time).accepted == final)
        try require(try context.checkpoint(session) == bytes)
    }

    @inline(never)
    private static func checkTrajectoryChildEvolution(_ context: TrajectoryEvolutionProbeContext) throws {
        let session = try context.session()
        defer { _ = session.shutdown() }
        let final = try context.advance(session, to: 0.04), state = final.accepted.checkpoint.physical
        guard let relativePosition = state.q.last, let relativeVelocity = state.v.last,
              let actualAcceleration = state.acceleration.last else { throw FoundationVerificationError.analyticCheckFailed }
        let oracle = try TrajectoryEvolutionProbeOracle(context.fixture, time: state.time,
            relativePosition: relativePosition, relativeVelocity: relativeVelocity)
        guard let acceleration = oracle.dynamicAcceleration else { throw FoundationVerificationError.analyticCheckFailed }
        let reference = try trajectoryChildReference(context.fixture, throughSteps: 4)
        try require(abs(relativePosition - reference.q) < 1e-9 && abs(relativeVelocity - reference.v) < 1e-9)
        try require(abs(actualAcceleration - acceleration) < 1e-9)
        try checkTrajectoryArray(Array(state.q.prefix(oracle.q.count)), oracle.q)
        try checkTrajectoryArray(Array(state.v.prefix(oracle.v.count)), oracle.v)
        let prefix = try context.checkpoint(session)
        _ = try context.inspect(session) { proof throws(RuntimeFailure) in
            do {
                guard let power = proof.partitionedPower else { throw FoundationVerificationError.analyticCheckFailed }
                try checkTrajectoryArray(power.rootActuationEffort, oracle.rootEffort)
                try checkTrajectoryEnergy(power, oracle)
                guard let actual = proof.acceleration.values.last else { throw FoundationVerificationError.analyticCheckFailed }
                try require(abs(actual - acceleration) < 1e-9)
            } catch { throw RuntimeFailure(.invalidState, message: "Independent trajectory physical witness failed.") }
        }
        try require(try context.checkpoint(session) == prefix && session.snapshot() == final.accepted)
        try checkTrajectoryChildWork(context, endpoint: oracle)
    }

    @inline(never)
    private static func trajectoryChildReference(_ fixture: TrajectoryEvolutionProbeModel,
                                                 throughSteps count: Int) throws -> (q: Double, v: Double) {
        var q = 0.0, v = 0.0
        let h = 0.01
        for i in 0..<count {
            let t = Double(i) * h
            let k1 = try trajectoryChildAcceleration(fixture, time: t, q: q, v: v)
            let v2 = v + h * k1 / 2
            let k2 = try trajectoryChildAcceleration(fixture, time: t + h / 2, q: q + h * v / 2, v: v2)
            let v3 = v + h * k2 / 2
            let k3 = try trajectoryChildAcceleration(fixture, time: t + h / 2, q: q + h * v2 / 2, v: v3)
            let v4 = v + h * k3
            let k4 = try trajectoryChildAcceleration(fixture, time: t + h, q: q + h * v3, v: v4)
            q += h * (v + 2 * v2 + 2 * v3 + v4) / 6
            v += h * (k1 + 2 * k2 + 2 * k3 + k4) / 6
        }
        return (q, v)
    }

    private static func trajectoryChildAcceleration(_ fixture: TrajectoryEvolutionProbeModel,
                                                    time: Double, q: Double, v: Double) throws -> Double {
        guard let acceleration = try TrajectoryEvolutionProbeOracle(fixture, time: time,
            relativePosition: q, relativeVelocity: v).dynamicAcceleration else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return acceleration
    }

    @inline(never)
    private static func checkTrajectoryChildWork(_ context: TrajectoryEvolutionProbeContext,
                                               endpoint: TrajectoryEvolutionProbeOracle) throws {
        var integral = 0.0
        for i in 0...4 {
            let point = try trajectoryChildReference(context.fixture, throughSteps: i)
            let physical = try context.state(time: Double(i) * 0.01, relativePosition: point.q, relativeVelocity: point.v)
            let power = try context.power(context.motion(physical))
            let weight = i == 0 || i == 4 ? 1.0 : (i % 2 == 0 ? 2.0 : 4.0)
            integral += weight * (power.rootActuationPower + power.drivePower)
        }
        let initial = try TrajectoryEvolutionProbeOracle(context.fixture, time: 0)
        try require(abs(integral * 0.01 / 3 - (endpoint.kineticEnergy - initial.kineticEnergy)) < 1e-8)
    }

    @inline(never)
    private static func checkTrajectoryKnotAndLaw(planar: Bool) throws {
        let query = TrajectoryEvolutionBoundaryProbe()
        let context = try TrajectoryEvolutionProbeContext(TrajectoryEvolutionProbeModel(planar: planar, piecewise: true),
            step: 0.07, boundaryQuery: query)
        let session = try context.session()
        defer { _ = session.shutdown() }
        let saved = try context.checkpoint(session)
        _ = try context.advance(session, to: 1)
        let knot = session.snapshot(), history = try context.history(session)
        try require(knot.checkpoint.physical.time.bitPattern == Double(1).bitPattern)
        try require(knot.checkpoint.acceptedSteps == 15 && history.acceptedTime.bitPattern == Double(1).bitPattern)
        let expected = try context.state(time: 1)
        try require(knot.checkpoint.physical.q == expected.q && knot.checkpoint.physical.acceleration == expected.acceleration)
        let final = try context.advance(session, to: 1.04).accepted, bytes = try context.checkpoint(session)
        try require(final.checkpoint.acceptedSteps == 16 && query.observedAcceptedKnot && query.calls == 16)
        try checkTrajectoryFreshReplay(context, saved: saved, final: final, bytes: bytes, time: 1.04)
        _ = try context.restore(session, bytes: saved)
        try require(try context.advance(session, to: 1.04).accepted == final)
        try require(try context.checkpoint(session) == bytes)
        try checkTrajectoryChangedLaw(context, saved: saved)
    }

    @inline(never)
    private static func checkTrajectoryChangedLaw(_ original: TrajectoryEvolutionProbeContext, saved: [UInt8]) throws {
        let context = try original.changedFutureLaw(offset: 0.125), session = try context.session()
        defer { _ = session.shutdown() }
        try require(context.initialState == original.initialState && context.fixture.model.stamp == original.fixture.model.stamp)
        let prefix = session.snapshot(), bytes = try context.checkpoint(session)
        var refused = false
        do throws(RuntimeFailure) { _ = try session.restart(saved, codec: NativeRuntimeCheckpointCodec()) }
        catch { try require(error.code == .incompatibleContinuation); refused = true }
        try require(refused && session.snapshot() == prefix && (try context.checkpoint(session)) == bytes)
    }

    @inline(never)
    private static func checkTrajectoryForgedAcceleration(_ context: TrajectoryEvolutionProbeContext,
                                                        session: TrajectoryEvolutionProbeContext.Session) throws {
        let prefix = session.snapshot(), old = prefix.checkpoint, physical = old.physical
        let saved = try context.checkpoint(session)
        var acceleration = physical.acceleration
        acceleration[0] += 0.1
        let state = try KinematicState(revision: physical.revision, time: physical.time,
            q: physical.q, v: physical.v, acceleration: acceleration)
        let checkpoint = try RuntimeCheckpoint(model: old.model, continuation: old.continuation, physical: state,
            contributors: old.contributors, random: old.random, acceptedSteps: old.acceptedSteps)
        let bytes = try NativeRuntimeCheckpointCodec().encode(checkpoint, capacity: context.configuration.capacity)
        var refused = false
        do throws(RuntimeFailure) { _ = try session.restart(bytes, codec: NativeRuntimeCheckpointCodec()) }
        catch { try require(error.code == .invalidState); refused = true }
        try require(refused && session.snapshot() == prefix && (try context.checkpoint(session)) == saved)
    }
}
