internal enum PrescribedTrajectoryMetadata {
    static func admit(_ trajectories:[PrescribedTrajectory],policy:PrescribedTrajectoryPolicy,
                      work:inout NumericalWork) throws(PrescribedMotionError) -> Int {
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        guard !trajectories.isEmpty,trajectories.count <= policy.motion.maximumSamples else { throw .capacityExceeded }
        var bytes=64,segments=0
        for trajectory in trajectories {
            guard trajectory.frame.key.utf8.count <= policy.motion.maximumIdentifierBytes,
                  trajectory.parentFrame.key.utf8.count <= policy.motion.maximumIdentifierBytes else { throw .capacityExceeded }
            segments=try PrescribedTrajectoryArithmetic.sum(segments,trajectory.segmentCount)
            guard segments <= policy.maximumSegments else { throw .capacityExceeded }
            let identifiers=try PrescribedTrajectoryArithmetic.sum(trajectory.frame.key.utf8.count,trajectory.parentFrame.key.utf8.count)
            let record=try PrescribedTrajectoryArithmetic.sum(800,try PrescribedTrajectoryArithmetic.sum(
                try PrescribedTrajectoryArithmetic.product(3,identifiers),try PrescribedTrajectoryArithmetic.product(500,trajectory.segmentCount)))
            bytes=try PrescribedTrajectoryArithmetic.sum(bytes,record)
            guard bytes <= policy.motion.maximumMetadataBytes else { throw .capacityExceeded }
        }
        let scalars=try PrescribedTrajectoryArithmetic.sum(bytes/8+1,try PrescribedTrajectoryArithmetic.sum(
            try PrescribedTrajectoryArithmetic.product(128,trajectories.count),try PrescribedTrajectoryArithmetic.product(64,segments)))
        try PrescribedBaseMotionArithmetic.reserve(scalars,operations:bytes,work:&work)
        return bytes
    }
    static func encode(_ trajectories:[PrescribedTrajectory],layout:BaseLayout?,angle:Double?,
                       policy:PrescribedTrajectoryPolicy,work:inout NumericalWork,admittedBytes:Int? = nil) throws(PrescribedMotionError) -> String {
        let bytes:Int
        if let admittedBytes { bytes=admittedBytes }
        else { bytes=try admit(trajectories,policy:policy,work:&work) }
        var result=layout == nil ? "trajectory-anchor-v1:c2-exact:right-knot:left-end" : "trajectory-base-v1:c2-exact:right-knot:left-end"
        result.reserveCapacity(bytes)
        func number(_ value:Double) { result.append(":");result.append(String(value.bitPattern,radix:16)) }
        func integer(_ value:Int) { result.append(":");result.append(String(value)) }
        func vector(_ value:Vector3) { number(value.x);number(value.y);number(value.z) }
        func identifier(_ value:EntityID) {
            integer(value.key.utf8.count);result.append(":")
            for byte in value.key.utf8 { result.append(String(byte,radix:16));result.append(".") }
        }
        func jet(_ value:PrescribedMotionJet) {
            vector(value.displacement);number(value.angle);vector(value.linearVelocity);number(value.angularRate)
            vector(value.linearAcceleration);number(value.angularAcceleration)
        }
        if let layout { integer(layout == .planarFloating ? 2 : 3);if let angle { number(angle) } }
        integer(trajectories.count)
        for t in trajectories {
            try PrescribedBaseMotionArithmetic.check(policy.motion)
            identifier(t.frame);identifier(t.parentFrame);number(t.referenceTime);number(t.minimumTime);number(t.maximumTime)
            vector(t.initialPose.translation);let q=t.initialPose.rotation
            number(q.w);number(q.x);number(q.y);number(q.z);vector(t.rotationAxis)
            switch t {
            case .quadratic(let m):
                integer(0);vector(m.translationRate);vector(m.translationAcceleration);number(m.angularRate);number(m.angularAcceleration)
            case .harmonic(let m):
                integer(1);vector(m.translationSine);vector(m.translationCosine)
                number(m.angularSine);number(m.angularCosine);number(m.frequency);number(m.phase)
            case .piecewise(let m):
                integer(2);integer(m.segments.count)
                for segment in m.segments {
                    try PrescribedBaseMotionArithmetic.check(policy.motion)
                    number(segment.startTime);number(segment.endTime);jet(segment.start);jet(segment.end)
                }
            }
        }
        guard result.utf8.count <= bytes else { throw .capacityExceeded }
        try PrescribedBaseMotionArithmetic.check(policy.motion);return result
    }
}
