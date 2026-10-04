internal enum PrescribedTrajectoryAdmission {
    static func admit(_ trajectories:[PrescribedTrajectory],metadata:String,policy:PrescribedTrajectoryPolicy,
                      work:inout NumericalWork) throws(PrescribedMotionError) {
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        guard !trajectories.isEmpty,trajectories.count <= policy.motion.maximumSamples,metadata.utf8.count <= policy.motion.maximumMetadataBytes else { throw .capacityExceeded }
        var segments=0
        for t in trajectories {
            guard t.frame.key.utf8.count <= policy.motion.maximumIdentifierBytes,t.parentFrame.key.utf8.count <= policy.motion.maximumIdentifierBytes else { throw .capacityExceeded }
            segments=try PrescribedTrajectoryArithmetic.sum(segments,t.segmentCount)
            guard segments <= policy.maximumSegments else { throw .capacityExceeded }
        }
        try reserve(metadataBytes:metadata.utf8.count,count:trajectories.count,segments:segments,work:&work)
    }
    static func admitBase(_ program:PrescribedBaseTrajectoryProgram,policy:PrescribedTrajectoryPolicy,
                          work:inout NumericalWork) throws(PrescribedMotionError) {
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        let t=program.trajectory
        guard program.metadata.utf8.count <= policy.motion.maximumMetadataBytes,
              t.frame.key.utf8.count <= policy.motion.maximumIdentifierBytes,
              t.parentFrame.key.utf8.count <= policy.motion.maximumIdentifierBytes,
              t.segmentCount <= policy.maximumSegments else { throw .capacityExceeded }
        try reserve(metadataBytes:program.metadata.utf8.count,count:1,segments:t.segmentCount,work:&work)
    }
    private static func reserve(metadataBytes:Int,count:Int,segments:Int,work:inout NumericalWork) throws(PrescribedMotionError) {
        let storage=try PrescribedTrajectoryArithmetic.sum(512,try PrescribedTrajectoryArithmetic.sum(metadataBytes/8+1,try PrescribedTrajectoryArithmetic.product(128,count)))
        // The sealed anchor outcome validates every frame pair; retain its original authority and admit that bounded comparison work.
        let operations=try PrescribedTrajectoryArithmetic.sum(try PrescribedTrajectoryArithmetic.product(metadataBytes,count),try PrescribedTrajectoryArithmetic.sum(
            try PrescribedTrajectoryArithmetic.product(2048,count),try PrescribedTrajectoryArithmetic.product(32,segments)))
        try PrescribedBaseMotionArithmetic.reserve(storage,operations:operations,work:&work)
    }
    static func time(_ time:Double,minimum:Double,maximum:Double) throws(PrescribedMotionError) {
        guard time.isFinite else { throw .invalidInput }
        guard time >= minimum,time <= maximum else { throw .outsideDomain }
    }
}
