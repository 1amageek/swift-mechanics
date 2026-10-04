
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol HybridEventEnvironment: Sendable {
    var catalog: HybridEventCatalog { get }
    /// Certify complete monotone closing-crossing intervals in the admitted equation/chart domain.
    /// Empty means no closing crossing in this segment; tangent/resting/uncertified motion must fail.
    func brackets(from source: RuntimeCheckpoint, to time: Double, cancellation: HybridCancellation) throws(HybridError) -> [HybridEventBracket]
    func sample(eventID: UInt64, state: RuntimeCheckpoint, work: inout CollisionWork, cancellation: HybridCancellation) throws(HybridError) -> HybridEventSample
    func impactInput(state: RuntimeCheckpoint, eventIDs: [UInt64], work: inout CollisionWork, cancellation: HybridCancellation) throws(HybridError) -> HardImpactInput
    /// Recompute smooth acceleration at unchanged time/q and supplied post-impulse v in the published chart.
    func postJump(physical: KinematicState, velocity: [Double]) throws(HybridError) -> KinematicState
}
