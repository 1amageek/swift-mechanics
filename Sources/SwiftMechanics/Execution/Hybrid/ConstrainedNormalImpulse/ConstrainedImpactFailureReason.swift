public enum ConstrainedImpactFailureReason: Error, Sendable {
    case invalidInput, capacityExceeded, sourceMismatch, unsupportedDomain, residualRejected, blockedNormalMode
    case rankAmbiguity(rank: Int, rows: Int)
    case supplierLedgerFailure
    case hybrid(HybridError)
    case constraint(ConstraintError)
    case dynamics(DynamicsError)
    case contact(ContactLawError)
    case load(LoadError)
    case numerical(NumericalError)
}
