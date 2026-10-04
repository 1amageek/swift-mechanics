internal enum ClosedLoopArithmetic {
    static func numeric<T>(_ operation: () throws(NumericalError) -> T) throws(ClosedLoopReactionError) -> T {
        do { return try operation() } catch { throw .numerical(error) }
    }
    static func core<T>(_ operation: () throws(CoreError) -> T) throws(ClosedLoopReactionError) -> T {
        do { return try operation() } catch { throw .core(error) }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(ClosedLoopReactionError) {
        try numeric { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func finite(_ value: Double) throws(ClosedLoopReactionError) -> Double {
        guard value.isFinite else { throw .invalidInput }; return value
    }
    static func check(_ policy: ClosedLoopReactionPolicy) throws(ClosedLoopReactionError) {
        guard !Task.isCancelled, !policy.tree.isCancelled(), !policy.geometry.evaluation.isCancelled(),
              !policy.rank.evaluation.isCancelled(), !policy.admission.isCancelled() else { throw .cancelled }
    }
    static func agrees(_ a: Vector3, _ b: Vector3, _ tolerance: NumericalTolerance) throws(ClosedLoopReactionError) -> Bool {
        try core { () throws(CoreError) in
            let x=try tolerance.contains(error:a.x-b.x,scale:max(abs(a.x),abs(b.x)))
            guard x else { return false }
            let y=try tolerance.contains(error:a.y-b.y,scale:max(abs(a.y),abs(b.y)))
            guard y else { return false }
            return try tolerance.contains(error:a.z-b.z,scale:max(abs(a.z),abs(b.z)))
        }
    }
    static func validate(_ before: NumericalWork, _ after: inout NumericalWork) throws(ClosedLoopReactionError) {
        guard before.budget == after.budget, after.operations >= before.operations,
              after.iterations >= before.iterations, after.peakScalarStorage >= before.peakScalarStorage else {
            after=before; throw .supplierLedgerReplaced
        }
    }
    static func merge(_ before: LoadWork, supplier: LoadWork, into caller: inout LoadWork) throws(ClosedLoopReactionError) {
        guard supplier.budget.maximumWork == before.budget.maximumWork, supplier.budget.maximumScalars == before.budget.maximumScalars,
              supplier.consumed >= before.consumed, supplier.peakScalars >= before.peakScalars else { throw .supplierLedgerReplaced }
        do { try caller.charge(supplier.consumed-before.consumed); try caller.reserve(scalars:supplier.peakScalars) }
        catch { throw .loadLedgerMerge(error) }
    }
}
