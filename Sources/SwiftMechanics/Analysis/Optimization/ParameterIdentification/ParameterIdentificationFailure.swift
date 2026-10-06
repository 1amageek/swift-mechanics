public struct ParameterIdentificationFailure: Error, Sendable {
    public let cause: IdentificationCause
    public let phase: IdentificationPhase
    public let work: NumericalWork
    public let loadWork: LoadWork
    public let supplierWork: DerivativeSupplierWork
    public let modelValidationAttempts: Int
    public let lastOriginalResidual: Double?
    public let lastObjective: Double?
    public let failedSupplierWorkUnavailable: Bool
}
