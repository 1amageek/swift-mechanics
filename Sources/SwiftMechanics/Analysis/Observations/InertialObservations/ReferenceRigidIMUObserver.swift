
public struct ReferenceRigidIMUObserver: RigidIMUObserving {
    private let kinematics:any KinematicObserving
    public init(kinematics:any KinematicObserving = ReferenceKinematicObserver()) { self.kinematics=kinematics }
    public func sample(source:ObservationSource,mount:ObservationMount,gravity:ObservationGravity,
                       policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> IMUObservation {
        try ObservationArithmetic.admit(source,policy:policy,work:&work)
        try ObservationArithmetic.metadata([gravity.model.identity,gravity.field.frame.key],policy:policy,work:&work)
        guard gravity.model == source.model.stamp,gravity.timeSeconds == source.state.state.time,
              gravity.field.frame == source.snapshot.tree.worldFrame else { throw .staleGravity }
        let mounted=try ObservationArithmetic.mounted(kinematics,source:source,mount:mount,policy:policy,work:&work)
        try ObservationArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(36) }
        let field=try ObservationArithmetic.core { () throws(CoreError) in
            try gravity.field.accelerationAtOrigin.adding(gravity.field.gradient.applying(to:mounted.sensorToWorld.translation))
        }
        let inverse=mounted.sensorToWorld.rotation.conjugated()
        let gyro=try ObservationArithmetic.core { () throws(CoreError) in try inverse.rotating(mounted.velocity.angular) }
        let specific=try ObservationArithmetic.core { () throws(CoreError) in try inverse.rotating(mounted.acceleration.linear.subtracting(field)) }
        try ObservationArithmetic.check(policy)
        return IMUObservation(header:ObservationHeader(source:source,mount:mount,frame:mount.sensorFrame),sensorToWorld:mounted.sensorToWorld,
            angularVelocitySensor:gyro,specificForceSensor:specific,worldAcceleration:mounted.acceleration.linear)
    }
}
