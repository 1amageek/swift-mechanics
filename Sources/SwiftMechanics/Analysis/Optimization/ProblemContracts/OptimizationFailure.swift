public struct OptimizationFailure: Error, Sendable {
    public let cause: OptimizationCause
    public let phase: OptimizationPhase
    public let isPhaseOne: Bool
    public let work: NumericalWork
    public let processedBases: Int
    public let lastFeasibilityResidual: Double?
    public let failedSupplierWorkUnavailable: Bool
    public var termination: OptimizationTermination {
        switch cause {
        case .invalidProblem, .dependentEqualityRows: .invalidProblem
        case .unsupportedDomain: .unsupportedDomain
        case .rankIndeterminate: .rankIndeterminate
        case .capacity: .resourceLimit
        case .nonconverged, .certificateRejected: .nonconverged
        case .cancelled: .cancelled
        case .nonFiniteResult: .arithmeticFailure
        case .invalidSupplierOutput, .invalidSupplierLedger: .supplierFailure
        case .numerical(let error):
            switch error.termination {
            case .resourceLimit: .resourceLimit
            case .cancelled: .cancelled
            case .unsupportedCapability: .unsupportedDomain
            case .arithmeticFailure: .arithmeticFailure
            default: .supplierFailure
            }
        }
    }
    internal init(cause: OptimizationCause, phase: OptimizationPhase, work: NumericalWork, processed: Int, residual: Double?, unavailable: Bool, isPhaseOne: Bool) {
        self.cause=cause; self.phase=phase; self.isPhaseOne=isPhaseOne; self.work=work; processedBases=processed; lastFeasibilityResidual=residual; failedSupplierWorkUnavailable=unavailable
    }
}
