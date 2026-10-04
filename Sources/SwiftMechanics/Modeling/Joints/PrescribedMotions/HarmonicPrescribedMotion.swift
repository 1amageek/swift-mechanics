public struct HarmonicPrescribedMotion: Sendable {
    public let frame:EntityID
    public let parentFrame:EntityID
    public let referenceTime:Double
    public let initialPose:RigidTransform
    public let translationSine:Vector3
    public let translationCosine:Vector3
    public let rotationAxis:Vector3
    public let angularSine:Double
    public let angularCosine:Double
    public let frequency:Double
    public let phase:Double
    public let minimumTime:Double
    public let maximumTime:Double
    public init(frame:EntityID,parentFrame:EntityID,referenceTime:Double,initialPose:RigidTransform,
                translationSine:Vector3,translationCosine:Vector3,rotationAxis:Vector3,
                angularSine:Double,angularCosine:Double,frequency:Double,phase:Double,
                minimumTime:Double,maximumTime:Double,maximumIdentifierBytes:Int) throws(PrescribedMotionError) {
        try PrescribedTrajectoryArithmetic.identity(frame,parent:parentFrame,pose:initialPose,axis:rotationAxis,maximumBytes:maximumIdentifierBytes)
        guard referenceTime.isFinite,minimumTime.isFinite,maximumTime.isFinite,
              minimumTime <= referenceTime,referenceTime <= maximumTime,frequency.isFinite,frequency > 0,
              (frequency*frequency).isFinite,phase.isFinite,angularSine.isFinite,angularCosine.isFinite else { throw .invalidInput }
        self.frame=frame;self.parentFrame=parentFrame;self.referenceTime=referenceTime;self.initialPose=initialPose
        self.translationSine=translationSine;self.translationCosine=translationCosine;self.rotationAxis=rotationAxis
        self.angularSine=angularSine;self.angularCosine=angularCosine;self.frequency=frequency;self.phase=phase
        self.minimumTime=minimumTime;self.maximumTime=maximumTime
    }
}
