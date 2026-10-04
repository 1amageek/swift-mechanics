public enum ReactionPathError: Error, Equatable, Sendable {
    case invalidInput, invalidShape, capacityExceeded, cancelled
    case unrepresentedConnections, nonuniqueGeneralizedAllocation, invalidSupplierEvidence, supplierLedgerReplaced
    case originalGeneralizedResidual(index: Int, scaledValue: Double)
    case originalBodyBalance(body: EntityID)
    case loadLedgerMerge(LoadError)
    case core(CoreError), joints(JointError), dynamics(DynamicsError), loads(LoadError), numerical(NumericalError)
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .supplierLedgerReplaced, .loadLedgerMerge: return true
        case .dynamics(let error):
            if case .numerical(_, let unavailable) = error { return unavailable }
            return false
        default: return false
        }
    }
}
