public enum ConstrainedImpactFailureReason: Error, Sendable {
    case invalidInput, capacityExceeded, sourceMismatch, unsupportedDomain, residualRejected, blockedNormalMode
    case rankAmbiguity(rank: Int, rows: Int)
    case supplierLedgerFailure
    indirect case hybrid(HybridError)
    indirect case constraint(ConstraintError)
    indirect case dynamics(DynamicsError)
    indirect case contact(ContactLawError)
    indirect case load(LoadError)
    indirect case numerical(NumericalError)
}
