import MechanicsNumerics

internal enum ConstraintArithmetic {
    static func check(_ policy: ConstraintEvaluationPolicy) throws(ConstraintError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func charge(_ n: Int, _ work: inout NumericalWork) throws(ConstraintError) {
        guard !Task.isCancelled else { throw .cancelled }
        do { try work.chargeOperations(n) } catch { throw .numerical(error) }
    }
    static func storage(_ n: Int, _ work: inout NumericalWork) throws(ConstraintError) {
        do { try work.requireStorage(n) } catch { throw .numerical(error) }
    }
    static func product(_ a: Int, _ b: Int) throws(ConstraintError) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) }
    }
    static func sum(_ a: Int, _ b: Int) throws(ConstraintError) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
    static func finite(_ x: Double) throws(ConstraintError) -> Double {
        guard x.isFinite else { throw .nonFiniteResult }; return x
    }
}
