@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol ConstrainedSleepEvolving: Sendable {
    func advanceToNextImpact(_ session:any RuntimeSessionOperating,through limit:Double,work:ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionFailure) -> ConstrainedSleepEvolutionResult
}
