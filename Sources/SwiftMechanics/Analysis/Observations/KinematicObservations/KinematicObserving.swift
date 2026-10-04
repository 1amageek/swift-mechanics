
public protocol KinematicObserving: Sendable {
    /// Mounted motion suppliers must match the original fixed-source/fixed-mount geometric computation exactly.
    /// Equivalent quaternion signs are admitted through rotation matrices; approximate alternatives are refused.
    func motion(source:ObservationSource,mount:ObservationMount,policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> MountedMotionObservation
    func encoder(source:ObservationSource,joint:EntityID,policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> JointEncoderObservation
}
