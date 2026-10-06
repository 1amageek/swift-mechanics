/// Only the original scene issuer can mint the admission consumed by this immutable owner.
public final class ContactRangeScene: Sendable {
    public let source: ObservationSource
    public let colliders: [ObservationColliderBinding]
    public let collision: CollisionSnapshot
    public let revision: UInt64
    internal init(admission: _ContactRangeSceneAdmission) {
        source=admission.source;colliders=admission.colliders;collision=admission.collision;revision=admission.revision
    }
}
