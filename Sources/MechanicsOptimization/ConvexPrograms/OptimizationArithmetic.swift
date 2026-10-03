import MechanicsNumerics
internal enum OptimizationArithmetic {
    static func check(_ policy: OptimizationPolicy) throws(OptimizationCause) { guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled } }
    static func charge(_ count: Int, policy: OptimizationPolicy, work: inout NumericalWork) throws(OptimizationCause) {
        try check(policy); do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func storage(_ count: Int,work: inout NumericalWork) throws(OptimizationCause) { do { try work.requireStorage(count) } catch { throw .numerical(error) } }
    static func sum(_ a: Int,_ b: Int) throws(OptimizationCause) -> Int { do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) } }
    static func product(_ a: Int,_ b: Int) throws(OptimizationCause) -> Int { do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) } }
    static func finite(_ value: Double) throws(OptimizationCause) -> Double { guard value.isFinite else { throw .nonFiniteResult }; return value }
    static func threshold(_ scale: Double,policy: OptimizationPolicy) throws(OptimizationCause) -> Double {
        try finite(policy.certificateAbsolute+policy.certificateRelative*max(1,scale))
    }
    static func capacity(_ resource: String,_ count: Int,_ limit: Int) throws(OptimizationCause) {
        guard count <= limit else { throw .capacity(resource:resource,required:count,limit:limit) }
    }
}
