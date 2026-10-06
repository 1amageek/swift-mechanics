internal enum ControlArithmetic {
    static func check(_ policy:ControlPolicy) throws(ControlFailure) {
        guard !policy.isCancelled(),!Task.isCancelled else { throw ControlFailure(.cancelled,phase:"work") }
    }
    static func charge(_ amount:Int,work:inout NumericalWork,policy:ControlPolicy) throws(ControlFailure) {
        try check(policy)
        do { try work.chargeOperations(amount) } catch { throw ControlFailure(.numerical(error),phase:"work") }
    }
    static func metadata(_ text:String,policy:ControlPolicy,work:inout NumericalWork) throws(ControlFailure) {
        var n=0
        for _ in text.utf8 { try charge(1,work:&work,policy:policy);guard n < policy.maximumMetadataBytes else { throw ControlFailure(.capacity,phase:"metadata") };n += 1 }
    }
    static func agrees(_ x:Double,_ y:Double,_ tolerance:NumericalTolerance) -> Bool {
        x.isFinite && y.isFinite && abs(x-y) <= tolerance.absolute+tolerance.relative*max(abs(x),abs(y))
    }
    static func runtime(_ failure:ControlFailure) -> RuntimeFailure {
        let code:RuntimeFailureCode
        switch failure.cause {
        case .cancelled,.actuation(.cancelled),.dynamics(.cancelled),.numerical(.cancelled):code = .cancelled
        case .invalidSupplierLedger:code = .invalidOwnerAccess
        case .capacity,.numerical(.resourceLimit),.actuation(.capacityExceeded),.actuation(.workExhausted):code = .capacityExceeded
        default:code = .invalidState
        }
        return RuntimeFailure(code,message:"Control phase " + failure.phase + " refused.",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable)
    }
}
