public enum DeformingContactError: Error, Sendable {
    case invalidInput, capacityExceeded, staleMesh, staleGeometry, invalidTopology, invertedCell, degenerateFace
    case adjacentPair, ambiguousFeature, outsideInterior, unsupportedDomain, staleHistory, invalidSupplierOutput, cancelled
    case physicalResidual, nonFinite, supplierLedgerReplaced
    case core(CoreError), numerical(NumericalError), flexible(FlexibleError)
    case collision(CollisionError, failedSupplierWorkUnavailable: Bool)
    case law(ContactLawError, failedSupplierWorkUnavailable: Bool)
    public var failedSupplierWorkUnavailable: Bool {
        switch self { case .supplierLedgerReplaced: true
        case .collision(_,let unavailable), .law(_,let unavailable): unavailable
        default: false }
    }
}
