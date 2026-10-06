public final class TriggerObservation: Sendable {
    public let scene: ContactRangeScene
    public let mount: ObservationMount
    public let mountedMotion: MountedMotionObservation
    public let update: CollisionTriggerUpdate
    public let witnesses: [CollisionWitness]
    /// Retains original exit geometry association without recursively retaining the entire sample history.
    public let exitedWitnesses: [CollisionWitness]
    public let filters: CollisionFilterPolicy
    public var sampleIndex: UInt64 { update.state.sampleIndex }
    public var timeSeconds: Double { scene.source.state.state.time }
    public var expressedFrame: EntityID { scene.source.snapshot.tree.worldFrame }
    internal init(admission: _TriggerObservationAdmission) {
        scene=admission.scene;mount=admission.mount;mountedMotion=admission.motion;update=admission.update
        witnesses=admission.witnesses;exitedWitnesses=admission.exited;filters=admission.filters
    }
}
