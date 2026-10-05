public final class TactileObservation: Sendable {
    public enum Side: Equatable, Sendable { case first, second }
    public let scene: ContactRangeScene
    public let mount: ObservationMount
    public let mountedMotion: MountedMotionObservation
    public let witness: CollisionWitness
    public let applicationPoint: Vector3
    public let basis: ContactBasis
    public let relativeVelocity: Vector3
    public let relativeAngularVelocity: Vector3
    public let response: ContactCurrentResponse
    public let side: Side
    /// On the mounted body, in sensor axes, about the sensor origin.
    public let force: Vector3
    public let couple: Vector3
    public var timeSeconds: Double { scene.source.state.state.time }
    public var expressedFrame: EntityID { mount.sensorFrame }
    public let forceUnit = PhysicalDimension.force
    public let coupleUnit = PhysicalDimension(length: 2, mass: 1, time: -2)
    public let temporalMeaning = ObservationHeader.TemporalMeaning.instantaneousContinuous
    internal init(admission: _TactileObservationAdmission) {
        scene=admission.scene;mount=admission.mount;mountedMotion=admission.motion;witness=admission.witness
        applicationPoint=admission.point;basis=admission.basis;relativeVelocity=admission.relative
        relativeAngularVelocity=admission.angular;response=admission.response;side=admission.side
        force=admission.force;couple=admission.couple
    }
}
