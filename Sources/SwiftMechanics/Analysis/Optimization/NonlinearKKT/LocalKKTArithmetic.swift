internal enum LocalKKTArithmetic {
    static func charge(_ n: Int,policy: LocalOptimizationPolicy,work: inout NumericalWork) throws(LocalOptimizationCause) {
        do { try KKTArithmetic.charge(n,work:&work,cancelled:policy.isCancelled) } catch { throw .callback(error) }
    }
    static func sum(_ a: Int,_ b: Int) throws(LocalOptimizationCause) -> Int { do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) } }
    static func product(_ a: Int,_ b: Int) throws(LocalOptimizationCause) -> Int { do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) } }
    static func threshold(_ scale: Double,policy: LocalOptimizationPolicy) throws(LocalOptimizationCause) -> Double {
        let value=policy.absoluteTolerance+policy.relativeTolerance*max(1,scale)
        guard value.isFinite else { throw .numerical(.nonFiniteResult) }; return value
    }
    static func capacity(_ value: Int,_ limit: Int) throws(LocalOptimizationCause) { guard value <= limit else { throw .capacity(required:value,limit:limit) } }
    static func finite(_ value: Double) throws(LocalOptimizationCause) -> Double { guard value.isFinite else { throw .numerical(.nonFiniteResult) }; return value }
}
