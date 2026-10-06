public final class RangeObservation: Sendable {
    public let scene: ContactRangeScene
    public let mount: ObservationMount
    public let mountedMotion: MountedMotionObservation
    public let ray: CollisionRay
    public let targets: [EntityID]
    /// Original world points/normals and source geometry; ordered by distance and collider identity.
    public let hits: [CollisionRayHit]
    public var timeSeconds: Double { scene.source.state.state.time }
    public var expressedFrame: EntityID { scene.source.snapshot.tree.worldFrame }
    public let distanceUnit = PhysicalDimension.length
    internal init(admission: _RangeObservationAdmission) {
        scene=admission.scene;mount=admission.mount;mountedMotion=admission.motion
        ray=admission.ray;targets=admission.targets;hits=admission.hits
    }
}
