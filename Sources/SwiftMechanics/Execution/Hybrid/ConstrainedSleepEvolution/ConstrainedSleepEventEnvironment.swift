@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol ConstrainedSleepEventEnvironment: Sendable {
    var catalog:HybridEventCatalog { get }
    var program:StationaryIslandProgram { get }
    var impactPolicy:ConstrainedImpactPolicy { get }
    var evolutionPolicy:HybridEvolutionPolicy { get }
    func brackets(from source:RuntimeCheckpoint,through time:Double,work:inout CollisionWork,cancellation:HybridCancellation) throws(HybridError) -> [HybridEventBracket]
    func sample(eventID:UInt64,endpoint:IslandSleepTrajectoryEndpoint,work:inout CollisionWork,cancellation:HybridCancellation) throws(HybridError) -> HybridEventSample
    func impactInput(endpoint:IslandSleepTrajectoryEndpoint,eventIDs:[UInt64],work:inout CollisionWork,cancellation:HybridCancellation) throws(HybridError) -> HardImpactInput
}
