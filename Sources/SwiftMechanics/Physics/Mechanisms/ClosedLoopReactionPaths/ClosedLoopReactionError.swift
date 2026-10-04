public enum ClosedLoopReactionError: Error, Sendable {
    case invalidInput, invalidShape, staleSource, capacityExceeded, cancelled
    case unsupportedPlanar, unsupportedSupportDomain, unsupportedTemporalMeaning, unrepresentedConnections
    case unallocatableGeneralizedLoad, ambiguousAllocation(nullity: Int), invalidRankEvidence
    case originalGeometry(row: UInt64), originalGeneralizedReaction(index: Int), originalActionReaction(row: UInt64)
    case invalidSupplierEvidence, supplierLedgerReplaced
    case loadLedgerMerge(LoadError)
    case geometry(GeometricConstraintError), constraint(ConstraintError), dynamics(DynamicsError)
    case tree(ReactionPathError), core(CoreError), loads(LoadError), numerical(NumericalError)
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .supplierLedgerReplaced, .loadLedgerMerge: return true
        case .geometry(let error): return error.failedSupplierWorkUnavailable
        case .tree(let error): return error.failedSupplierWorkUnavailable
        case .dynamics(let error):
            if case .numerical(_,let missing)=error { return missing }; return false
        case .constraint(let error):
            switch error { case .linear(_,let missing): return missing; case .nonlinear(let failure): return failure.failedSupplierWorkUnavailable; default: return false }
        default: return false
        }
    }
}
