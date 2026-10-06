public struct FrictionalImpulseFailure: Error, Sendable {
    public let cause: FrictionalImpulseCause
    /// A terminal supplier failure can expose only its known prefix, never invented total work.
    public let failedSupplierWorkUnavailable: Bool
    public init(_ cause: FrictionalImpulseCause, failedSupplierWorkUnavailable: Bool = false) {
        self.cause=cause; self.failedSupplierWorkUnavailable=failedSupplierWorkUnavailable
    }
}
