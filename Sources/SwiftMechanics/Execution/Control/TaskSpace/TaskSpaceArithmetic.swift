internal enum TaskSpaceArithmetic {
    static func check(_ system: PhysicalRigidDynamicsSystem, _ policy: TaskSpacePolicy) throws(TaskSpaceFailure) {
        guard !Task.isCancelled, !policy.isCancelled(), !system.admission.isCancelled() else { throw TaskSpaceFailure(.cancelled) }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(TaskSpaceFailure) {
        do { try work.chargeOperations(count) } catch { throw TaskSpaceFailure(.numerical(error)) }
    }
    static func product(_ a: Int, _ b: Int) throws(TaskSpaceFailure) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw TaskSpaceFailure(.numerical(error)) }
    }
    static func sum(_ a: Int, _ b: Int) throws(TaskSpaceFailure) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw TaskSpaceFailure(.numerical(error)) }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(TaskSpaceFailure) {
        do { try work.requireStorage(count) } catch { throw TaskSpaceFailure(.numerical(error)) }
    }
    static func finite(_ value: Double) throws(TaskSpaceFailure) -> Double {
        guard value.isFinite else { throw TaskSpaceFailure(.nonFiniteResult) }; return value
    }
    static func core<Value>(_ operation: () throws(CoreError) -> Value) throws(TaskSpaceFailure) -> Value {
        do { return try operation() } catch { throw TaskSpaceFailure(.core(error)) }
    }
    static func dot(_ a: [Double], _ b: [Double], work: inout NumericalWork) throws(TaskSpaceFailure) -> Double {
        guard a.count == b.count else { throw TaskSpaceFailure(.invalidShape) }
        var result = 0.0
        for i in a.indices { try charge(2,&work); result = try finite(result + a[i]*b[i]) }
        return result
    }
    static func threshold(_ tolerance: NumericalTolerance, scale: Double, work: inout NumericalWork) throws(TaskSpaceFailure) -> Double {
        try charge(2,&work); return try finite(tolerance.absolute + tolerance.relative*scale)
    }
    static func seed(_ work: NumericalWork, reserved: Int) throws(TaskSpaceFailure) -> NumericalWork {
        do { var local = NumericalWork(budget: try work.remainingBudget(reservedStorage:reserved)); try local.chargeOperations(1); return local }
        catch { throw TaskSpaceFailure(.numerical(error)) }
    }
    static func reconcile(_ local: NumericalWork, before: NumericalWork, reserved: Int,
                          work: inout NumericalWork) throws(TaskSpaceFailure) {
        let valid = local.budget == before.budget && local.operations >= before.operations && local.iterations >= before.iterations &&
            local.peakScalarStorage >= before.peakScalarStorage && local.operations <= local.budget.arithmeticOperations &&
            local.iterations <= local.budget.iterations && local.peakScalarStorage <= local.budget.scalarStorage
        do { try work.absorb(valid ? local : before,reservedStorage:reserved) }
        catch { throw TaskSpaceFailure(.numerical(error),failedSupplierWorkUnavailable:!valid) }
        guard valid else { throw TaskSpaceFailure(.invalidSupplierLedger,failedSupplierWorkUnavailable:true) }
    }
    /// Two-pass row orthogonalization in dimensionless q/v-scaled point coordinates.
    static func rank(_ rows: [Double], count m: Int, width n: Int, relative: Double,
                     system: PhysicalRigidDynamicsSystem, policy: TaskSpacePolicy,
                     work: inout NumericalWork) throws(TaskSpaceFailure) -> Int {
        var basis = [Double](repeating:0,count:rows.count), scratch = [Double](repeating:0,count:n), rank = 0
        for row in 0..<m {
            try check(system,policy)
            var scale = 0.0
            for i in 0..<n { try charge(2,&work); scratch[i] = rows[row*n+i]; scale = max(scale,abs(scratch[i])) }
            if scale == 0 { continue }
            // Row scaling avoids overflow while preserving the relative rank decision.
            for i in 0..<n { try charge(1,&work); scratch[i] /= scale }
            let original = try finite(dot(scratch,scratch,work:&work).squareRoot())
            for _ in 0..<2 {
                for k in 0..<rank {
                    var projection = 0.0
                    for i in 0..<n { try charge(2,&work); projection = try finite(projection + scratch[i]*basis[k*n+i]) }
                    for i in 0..<n { try charge(2,&work); scratch[i] = try finite(scratch[i] - projection*basis[k*n+i]) }
                }
            }
            let norm = try finite(dot(scratch,scratch,work:&work).squareRoot())
            try charge(1,&work)
            if rank < n, norm > relative*original {
                for i in 0..<n { try charge(1,&work); basis[rank*n+i] = try finite(scratch[i]/norm) }
                rank += 1
            }
        }
        return rank
    }
}
