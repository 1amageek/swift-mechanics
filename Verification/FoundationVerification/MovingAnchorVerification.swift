import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifyMovingAnchorRuntime() throws {
        let context = try MovingAnchorProbeContext()
        try verifyMovingAnchorContinuation(context)
        print("AF23 complete anchors: exact v2 cold replay, original derivatives and rejected-prefix preservation passed")
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyMovingAnchorContinuation(_ context: MovingAnchorProbeContext) throws {
        let first = try context.session(), second = try context.session()
        defer { _ = first.shutdown(); _ = second.shutdown() }
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        _ = try advanceMovingAnchor(first)
        let prefix = try first.checkpoint(codec: codec)
        let restored = try second.restart(prefix, codec: codec)
        try require(try second.checkpoint(codec: codec) == prefix)
        try require(sameMovingAnchorBits(first.snapshot().physical.state, restored.physical.state))
        try verifyMovingAnchorPose(context, restored.physical.state)
        _ = try first.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 1); _ = try trial.nextRandom()
            try trial.setTime(0.5); try trial.setPrescribedAnchor(MovingAnchorProbeContext.sample(time: 0.5))
            try trial.setPosition(99, at: 0); return .reject
        }
        try require(try first.checkpoint(codec: codec) == prefix)
        var staleRefused = false
        do throws(RuntimeFailure) {
            _ = try first.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                try control.beginWorkBlock(units: 1); _ = try trial.nextRandom()
                try trial.setTime(0.5); return .accept
            }
        } catch { try require(error.code == .invalidState); staleRefused = true }
        try require(staleRefused && (try first.checkpoint(codec: codec)) == prefix)
        _ = try advanceMovingAnchor(first); _ = try advanceMovingAnchor(second)
        try require(try first.checkpoint(codec: codec) == second.checkpoint(codec: codec))
        try require(sameMovingAnchorBits(first.snapshot().physical.state, second.snapshot().physical.state))
        try require(first.profile().reservedPhysicalScalars == 23)
        try verifyMovingAnchorPose(context, first.snapshot().physical.state)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func advanceMovingAnchor(_ session: any RuntimeSessionOperating) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 1)
            let count = try ProbeRuntimeContributors.count(trial.contributor("probe-counter"))
            guard count < UInt64.max else { throw RuntimeFailure(.capacityExceeded, message: "Public anchor counter overflow.") }
            let random = try trial.nextRandom(), time = trial.timeSeconds + 0.25
            let sample = try MovingAnchorProbeContext.sample(time: time)
            _ = try trial.prescribedAnchor(sample.frame)
            try trial.setPrescribedAnchor(sample); try trial.setTime(time)
            try trial.setPosition(trial.position(at: 0) + Double((random & 15) + 1) / 16, at: 0)
            try trial.setVelocity(Double(count + 1), at: 0); try trial.setAcceleration(0.75, at: 0)
            try trial.replaceContributor(ProbeRuntimeContributors.record(count + 1)); return .accept
        }
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyMovingAnchorPose(_ context: MovingAnchorProbeContext, _ state: KinematicState) throws {
        let body = try context.model.evaluate(context.model.makeState(state)).body(context.child).motion
        let time = state.time, angle = 0.3 + 0.4 * time + 0.1 * time * time + state.q[0]
        let expected = try UnitQuaternion(axis: .unitZ, angle: angle).matrix()
        let actual = try body.pose.rotation.matrix()
        try require(abs(body.pose.translation.x - (0.2 + 0.6 * time + 0.15 * time * time)) < 1e-12)
        try require(abs(actual.m00 - expected.m00) < 1e-12)
        try require(abs(actual.m10 - expected.m10) < 1e-12)
        try require(abs(body.velocity.angular.z - (0.4 + 0.2 * time + state.v[0])) < 1e-12)
        try require(abs(body.acceleration.angular.z - (0.2 + state.acceleration[0])) < 1e-12)
        try require(abs(body.velocity.linear.x - (0.6 + 0.3 * time)) < 1e-12)
        try require(abs(body.acceleration.linear.x - 0.3) < 1e-12)
    }

    private static func sameMovingAnchorBits(_ lhs: KinematicState, _ rhs: KinematicState) -> Bool {
        guard lhs.revision == rhs.revision, lhs.time.bitPattern == rhs.time.bitPattern,
              lhs.q.count == rhs.q.count, lhs.v.count == rhs.v.count,
              lhs.acceleration.count == rhs.acceleration.count,
              lhs.prescribedAnchors.count == rhs.prescribedAnchors.count else { return false }
        for index in lhs.q.indices { if lhs.q[index].bitPattern != rhs.q[index].bitPattern { return false } }
        for index in lhs.v.indices { if lhs.v[index].bitPattern != rhs.v[index].bitPattern { return false } }
        for index in lhs.acceleration.indices { if lhs.acceleration[index].bitPattern != rhs.acceleration[index].bitPattern { return false } }
        for index in lhs.prescribedAnchors.indices {
            let a = lhs.prescribedAnchors[index], b = rhs.prescribedAnchors[index]
            guard a.frame == b.frame, a.time.bitPattern == b.time.bitPattern else { return false }
            let ar = a.motion.pose.rotation, br = b.motion.pose.rotation
            guard ar.w.bitPattern == br.w.bitPattern, ar.x.bitPattern == br.x.bitPattern,
                  ar.y.bitPattern == br.y.bitPattern, ar.z.bitPattern == br.z.bitPattern else { return false }
            let av = [a.motion.pose.translation, a.motion.velocity.angular, a.motion.velocity.linear,
                      a.motion.acceleration.angular, a.motion.acceleration.linear]
            let bv = [b.motion.pose.translation, b.motion.velocity.angular, b.motion.velocity.linear,
                      b.motion.acceleration.angular, b.motion.acceleration.linear]
            for slot in av.indices {
                guard av[slot].x.bitPattern == bv[slot].x.bitPattern, av[slot].y.bitPattern == bv[slot].y.bitPattern,
                      av[slot].z.bitPattern == bv[slot].z.bitPattern else { return false }
            }
        }
        return true
    }
}
