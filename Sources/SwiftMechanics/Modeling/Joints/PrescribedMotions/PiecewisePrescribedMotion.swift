public struct PiecewisePrescribedMotion: Sendable {
    public let frame:EntityID
    public let parentFrame:EntityID
    public let initialPose:RigidTransform
    public let rotationAxis:Vector3
    public let segments:[PrescribedMotionSegment]
    public var referenceTime:Double { segments[0].startTime }
    public var minimumTime:Double { referenceTime }
    public var maximumTime:Double { segments[segments.count-1].endTime }
    public init(frame:EntityID,parentFrame:EntityID,initialPose:RigidTransform,rotationAxis:Vector3,
                segments:[PrescribedMotionSegment],policy:PrescribedTrajectoryPolicy,
                work:inout NumericalWork) throws(PrescribedMotionError) {
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        guard !segments.isEmpty,segments.count <= policy.maximumSegments else { throw .capacityExceeded }
        try PrescribedTrajectoryArithmetic.reserve(count:segments.count,scalars:64,operations:512,work:&work)
        try PrescribedTrajectoryArithmetic.identity(frame,parent:parentFrame,pose:initialPose,axis:rotationAxis,maximumBytes:policy.motion.maximumIdentifierBytes)
        guard segments[0].start.displacement == .zero,segments[0].start.angle == 0 else { throw .invalidInput }
        for i in segments.indices {
            try PrescribedBaseMotionArithmetic.check(policy.motion)
            try PrescribedTrajectoryArithmetic.validatePolynomial(segments[i])
            if i > 0 {
                guard segments[i-1].endTime == segments[i].startTime else { throw .invalidInput }
                try PrescribedTrajectoryArithmetic.continuity(segments[i-1].end,segments[i].start,time:segments[i].startTime)
            }
        }
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        self.frame=frame;self.parentFrame=parentFrame;self.initialPose=initialPose;self.rotationAxis=rotationAxis;self.segments=segments
    }
}
