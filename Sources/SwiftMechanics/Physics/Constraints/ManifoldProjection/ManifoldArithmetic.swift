internal enum ManifoldArithmetic {
    static func geometry<T>(_ operation: () throws -> T) throws(GeometricConstraintError) -> T {
        do { return try operation() } catch { throw .invalidGeometry }
    }
    static func numeric<T>(_ operation: () throws(NumericalError) -> T) throws(GeometricConstraintError) -> T {
        do throws(NumericalError) { return try operation() } catch { throw .numerical(error) }
    }
    static func charge(_ count:Int,_ work:inout NumericalWork) throws(GeometricConstraintError) {
        do throws(NumericalError) { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func check(_ policy:ConstraintEvaluationPolicy) throws(GeometricConstraintError) {
        guard !Task.isCancelled,!policy.isCancelled() else { throw .cancelled }
    }
    static func finite(_ value:Double) throws(GeometricConstraintError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult };return value
    }
}
