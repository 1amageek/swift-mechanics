import MechanicsNumerics

internal enum MechanismArithmetic {
    static func numerical<T>(_ operation: () throws(NumericalError) -> T) throws(MechanismError) -> T {
        do throws(NumericalError) { return try operation() } catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(MechanismError) {
        try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func finite(_ value: Double) throws(MechanismError) -> Double {
        guard value.isFinite else { throw .nonfinite }; return value
    }
    static func check(_ policy: MechanismSolvePolicy) throws(MechanismError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func preserved(_ before: NumericalWork, _ after: NumericalWork) -> Bool {
        before.budget == after.budget && after.operations >= before.operations && after.iterations >= before.iterations && after.peakScalarStorage >= before.peakScalarStorage
    }
}
