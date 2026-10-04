
public protocol RigidIMUObserving: Sendable {
    /// Injected mounted evidence must be exactly reference-equivalent for the complete original source and mount.
    func sample(source:ObservationSource,mount:ObservationMount,gravity:ObservationGravity,
                policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> IMUObservation
}
