public struct ImplicitIntegrationFailure: Error, Sendable {
    public let cause: ImplicitMethodCause
    public let lastAccepted: RuntimeAcceptedState
    public let work: NumericalWork
    public let failedSupplierWorkUnavailable: Bool
}
