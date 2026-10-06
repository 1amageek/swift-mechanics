internal enum IslandArithmetic {
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(StationaryIslandFailureReason) -> T {
        do throws(NumericalError) { return try body() } catch { throw .numerical(error) }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(StationaryIslandFailureReason) {
        try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(StationaryIslandFailureReason) {
        try numerical { () throws(NumericalError) in try work.requireStorage(count) }
    }
    static func product(_ a: Int, _ b: Int) throws(StationaryIslandFailureReason) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.product(a,b) }
    }
    static func sum(_ a: Int, _ b: Int) throws(StationaryIslandFailureReason) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.sum(a,b) }
    }
    static func check(_ policy: StationaryIslandPolicy) throws(StationaryIslandFailureReason) {
        guard !Task.isCancelled, !policy.mechanics.isCancelled(), !policy.admission.isCancelled(),
              !policy.mechanics.constraints.evaluation.isCancelled() else { throw .cancelled }
    }
    static func unavailable(_ reason: StationaryIslandFailureReason) -> Bool {
        switch reason {
        case .compilation, .kinematics, .supplierLedgerFailure: return true
        case .mechanism(let e): return e.failedSupplierWorkUnavailable
        case .dynamics(let e): return e.failedSupplierWorkUnavailable
        case .constraint(let e): return MechanismError.constraint(e).failedSupplierWorkUnavailable
        default:return false
        }
    }
    static func cancelled(_ reason: StationaryIslandFailureReason) -> Bool {
        switch reason {
        case .cancelled,.load(.cancelled),.numerical(.cancelled):return true
        case .constraint(let error):
            switch error {
            case .cancelled,.numerical(.cancelled),.linear(.cancelled,_):return true
            case .nonlinear(let failure):return failure.termination == .cancelled
            default:return false
            }
        case .dynamics(let error):
            switch error { case .cancelled,.loads(.cancelled),.numerical(.cancelled,_):return true;default:return false }
        case .mechanism(let error):
            switch error {
            case .cancelled,.numerical(.cancelled,_):return true
            case .dynamics(let original):return cancelled(.dynamics(original))
            case .constraint(let original):return cancelled(.constraint(original))
            default:return false
            }
        default:return false
        }
    }
}
