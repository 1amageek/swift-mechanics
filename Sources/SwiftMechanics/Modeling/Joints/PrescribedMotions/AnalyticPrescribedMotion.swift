/// Identified relative motion expressed at the moving origin in parent-frame axes.
public struct AnalyticPrescribedMotion: Equatable, Sendable {
    public let frame:EntityID
    public let parentFrame:EntityID
    public let referenceTime:Double
    public let initialPose:RigidTransform
    public let translationRate:Vector3
    public let translationAcceleration:Vector3
    public let rotationAxis:Vector3
    public let angularRate:Double
    public let angularAcceleration:Double
    public let minimumTime:Double
    public let maximumTime:Double
    public init(frame:EntityID,parentFrame:EntityID,referenceTime:Double,initialPose:RigidTransform,
                translationRate:Vector3,translationAcceleration:Vector3,rotationAxis:Vector3,
                angularRate:Double,angularAcceleration:Double,minimumTime:Double,maximumTime:Double,
                maximumIdentifierBytes:Int) throws(PrescribedMotionError) {
        guard maximumIdentifierBytes > 0,frame.key.utf8.count <= maximumIdentifierBytes,
              parentFrame.key.utf8.count <= maximumIdentifierBytes else { throw .capacityExceeded }
        guard frame.kind == .frame,parentFrame.kind == .frame,frame != parentFrame else { throw .invalidFrame }
        guard referenceTime.isFinite,angularRate.isFinite,angularAcceleration.isFinite,
              minimumTime.isFinite,maximumTime.isFinite,minimumTime <= referenceTime,referenceTime <= maximumTime else { throw .invalidInput }
        let norm:Double
        do throws(CoreError) {
            _=try UnitQuaternion(unitW:initialPose.rotation.w,x:initialPose.rotation.x,y:initialPose.rotation.y,z:initialPose.rotation.z)
            norm=try rotationAxis.dot(rotationAxis)
        } catch { throw .mathematical(error) }
        guard abs(norm-1) <= 16*Double.ulpOfOne else { throw .invalidAxis }
        self.frame=frame;self.parentFrame=parentFrame;self.referenceTime=referenceTime;self.initialPose=initialPose
        self.translationRate=translationRate;self.translationAcceleration=translationAcceleration;self.rotationAxis=rotationAxis
        self.angularRate=angularRate;self.angularAcceleration=angularAcceleration;self.minimumTime=minimumTime;self.maximumTime=maximumTime
    }
}
