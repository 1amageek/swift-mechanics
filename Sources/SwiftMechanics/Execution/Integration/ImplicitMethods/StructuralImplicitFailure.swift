public struct StructuralImplicitFailure: Error, Sendable {
    public let cause: ImplicitMethodCause
    public let input: StructuralIntegrationState
    public let work: NumericalWork
    public let failedSupplierWorkUnavailable: Bool
}
