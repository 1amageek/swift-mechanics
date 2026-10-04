import SwiftMechanics

/// Uses a genuine original query while deliberately substituting the fixed mount under unchanged identities.
internal struct ChangedMountKinematicObserver:KinematicObserving {
    func motion(source:ObservationSource,mount:ObservationMount,policy:ObservationPolicy,
                work:inout NumericalWork) throws(ObservationError) -> MountedMotionObservation {
        let transform:RigidTransform
        do throws(CoreError) {
            transform=try RigidTransform(rotation:mount.sensorToBody.rotation,
                translation:mount.sensorToBody.translation.adding(.unitX))
        } catch { throw .core(error) }
        let changed=try ObservationMount(sensor:mount.sensor,body:mount.body,sensorFrame:mount.sensorFrame,sensorToBody:transform)
        return try ReferenceKinematicObserver().motion(source:source,mount:changed,policy:policy,work:&work)
    }
    func encoder(source:ObservationSource,joint:EntityID,policy:ObservationPolicy,
                 work:inout NumericalWork) throws(ObservationError) -> JointEncoderObservation {
        try ReferenceKinematicObserver().encoder(source:source,joint:joint,policy:policy,work:&work)
    }
}
