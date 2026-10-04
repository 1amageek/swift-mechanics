
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol NormalImpulseSolving: Sendable {
    func solve(_ impact: PreparedImpact, policy: HybridPolicy, massPolicy: DynamicsSolvePolicy,
               work: inout NumericalWork, contactWork: inout ContactWork, cancellation: HybridCancellation) throws(HybridError) -> NormalImpulseResult
}
