internal enum ConstrainedImpactArithmetic {
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(ConstrainedImpactError) -> T {
        do { return try body() } catch { throw ConstrainedImpactError(.numerical(error)) }
    }
    static func finite(_ value: Double) throws(ConstrainedImpactError) -> Double {
        guard value.isFinite else { throw ConstrainedImpactError(.numerical(.nonFiniteResult)) }; return value
    }
    static func product(_ a: Int, _ b: Int) throws(ConstrainedImpactError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.product(a,b) }
    }
    static func sum(_ a: Int, _ b: Int) throws(ConstrainedImpactError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.sum(a,b) }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(ConstrainedImpactError) {
        guard !Task.isCancelled else { throw ConstrainedImpactError(.numerical(.cancelled)) }
        try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(ConstrainedImpactError) {
        guard !Task.isCancelled else { throw ConstrainedImpactError(.numerical(.cancelled)) }
        try numerical { () throws(NumericalError) in try work.requireStorage(count) }
    }
    static func dot(_ a: [Double], _ b: [Double], work: inout NumericalWork) throws(ConstrainedImpactError) -> Double {
        guard a.count == b.count else { throw ConstrainedImpactError(.invalidInput) }
        try charge(try product(2,a.count),&work)
        var value = 0.0
        for i in a.indices { value = try finite(value+a[i]*b[i]) }
        return value
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func check(_ cancellation: HybridCancellation) throws(ConstrainedImpactError) {
        do { try cancellation.check() } catch { throw ConstrainedImpactError(.hybrid(error)) }
    }
    static func isCancelled(_ reason: ConstrainedImpactFailureReason) -> Bool {
        switch reason {
        case .hybrid(.cancelled), .constraint(.cancelled), .dynamics(.cancelled), .contact(.cancelled), .load(.cancelled), .numerical(.cancelled): return true
        case .dynamics(.numerical(.cancelled,_)), .constraint(.numerical(.cancelled)), .constraint(.linear(.cancelled,_)): return true
        case .hybrid(.dynamics(let error)): return isCancelled(.dynamics(error))
        case .hybrid(.contact(.cancelled)), .hybrid(.numerical(.cancelled)): return true
        default: return false
        }
    }
    static func unavailable(_ reason: ConstrainedImpactFailureReason) -> Bool {
        switch reason {
        case .dynamics(let error): return error.failedSupplierWorkUnavailable
        case .hybrid(let error): return error.failedSupplierWorkUnavailable
        case .constraint(.linear(_,let flag)): return flag
        case .constraint(.nonlinear): return true
        default: return false
        }
    }
}
