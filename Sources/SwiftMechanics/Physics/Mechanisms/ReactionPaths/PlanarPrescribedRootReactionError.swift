public enum PlanarPrescribedRootReactionError: Error, Sendable {
    case invalidInput, invalidShape, staleSource, capacityExceeded, cancelled
    case unsupportedSupportDomain, unsupportedTemporalMeaning, unrepresentedConnections, unallocatableGeneralizedLoad
    case invalidRankEvidence, originalRootRow(row: UInt64), originalGeneralizedReaction(index: Int), originalRootEffort(index: Int)
    case invalidSupplierEvidence, supplierLedgerReplaced, loadLedgerMerge(LoadError)
    case geometry(GeometricConstraintError), motion(PrescribedMotionError), mechanism(MechanismError)
    case constraint(ConstraintError), tree(ReactionPathError), core(CoreError), dynamics(DynamicsError)
    case loads(LoadError), numerical(NumericalError)
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .supplierLedgerReplaced, .loadLedgerMerge: true
        case .geometry(let e): e.failedSupplierWorkUnavailable
        case .motion(let e): e.failedSupplierWorkUnavailable
        case .mechanism(let e): e.failedSupplierWorkUnavailable
        case .tree(let e): e.failedSupplierWorkUnavailable
        case .dynamics(let e): e.failedSupplierWorkUnavailable
        case .constraint(let e):
            switch e { case .linear(_,let missing): missing; case .nonlinear(let f): f.failedSupplierWorkUnavailable; default: false }
        default: false
        }
    }
}
