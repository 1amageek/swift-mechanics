import MechanicsRuntime

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol HybridEvolving: Sendable {
    func advance(_ session: any RuntimeSessionOperating, to time: Double, work: HybridEvolutionWork,
                 cancellation: HybridCancellation) throws(HybridEvolutionFailure) -> HybridEvolutionResult
}
