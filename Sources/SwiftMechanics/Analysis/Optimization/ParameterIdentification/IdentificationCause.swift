public enum IdentificationCause: Error, Sendable {
    case invalidSource, invalidObservation, invalidUnits, invalidBounds, unsupportedDomain
    case capacity, cancelled, nonFiniteResult, originalEvidenceRejected, invalidSupplierOutput, invalidSupplierLedger
    case unidentifiable(rank: Int, identifiableDirection: [Double], nullDirection: [Double], originalNullResidual: Double)
    case rankIndeterminate(pivot: Double, threshold: Double)
    case core(CoreError)
    case model(ModelError)
    case loads(LoadError)
    case dynamics(DynamicsError)
    case derivative(DerivativeError)
    case optimization(OptimizationFailure)
    case numerical(NumericalError)
}
