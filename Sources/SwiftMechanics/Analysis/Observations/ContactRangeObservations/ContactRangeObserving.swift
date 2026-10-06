public protocol ContactRangeObserving: Sendable {
    /// Ray origin and direction are in the fixed sensor's axes. Success is exactly reference-equivalent.
    func range(scene: ContactRangeScene, mount: ObservationMount, ray: CollisionRay, targets: [EntityID],
               policy: ContactRangeObservationPolicy, collisionWork: inout CollisionWork, work: inout NumericalWork)
        throws(ContactRangeObservationError) -> RangeObservation
    /// Sampled overlap events, without Runtime acceptance or continuous crossing authority.
    func triggers(scene: ContactRangeScene, mount: ObservationMount, filters: CollisionFilterPolicy,
                  previous: TriggerObservation?, sampleIndex: UInt64, policy: ContactRangeObservationPolicy,
                  collisionWork: inout CollisionWork, work: inout NumericalWork)
        throws(ContactRangeObservationError) -> TriggerObservation
    /// Current force/couple only; history acceptance is the caller's explicit declaration.
    func tactile(scene: ContactRangeScene, mount: ObservationMount, contact: TactileContactBinding,
                 policy: ContactRangeObservationPolicy, collisionWork: inout CollisionWork,
                 contactWork: inout ContactWork, work: inout NumericalWork)
        throws(ContactRangeObservationError) -> TactileObservation
}
