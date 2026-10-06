public protocol ConstrainedNormalImpulseSolving: Sendable {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    func solve(_ prepared: PreparedConstrainedImpact, work: inout NumericalWork, contactWork: inout ContactWork,
               cancellation: HybridCancellation) throws(ConstrainedImpactError) -> ConstrainedNormalImpulseResult
}
