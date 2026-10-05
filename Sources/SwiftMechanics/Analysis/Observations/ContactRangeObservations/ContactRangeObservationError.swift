public enum ContactRangeObservationError: Error, Sendable {
    case invalidInput, unsupportedSensorModel, unsupportedRepresentation, unsupportedChart
    case staleSource, invalidSupplierEvidence, supplierLedgerReplaced, temporalMismatch
    case capacityExceeded, cancelled
    case observation(ObservationError), collision(CollisionError), current(ContactCurrentError)
    case observationSupplier(ObservationError), collisionSupplier(CollisionError), currentSupplier(ContactCurrentError)
    case core(CoreError), numerical(NumericalError)
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .supplierLedgerReplaced, .observationSupplier, .collisionSupplier, .currentSupplier: true
        case .observation(let error): error.failedSupplierWorkUnavailable
        default: false
        }
    }
}
