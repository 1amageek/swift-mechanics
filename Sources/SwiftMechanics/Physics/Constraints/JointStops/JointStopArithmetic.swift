internal enum JointStopArithmetic {
    static func check(_ policy: JointStopPolicy) throws(JointStopFailure) {
        guard !Task.isCancelled, !policy.observations.isCancelled(), !policy.constraints.isCancelled(),
              !policy.admission.isCancelled() else { throw JointStopFailure(.cancelled) }
    }
    static func numerical<Value>(_ operation: () throws(NumericalError) -> Value) throws(JointStopFailure) -> Value {
        do throws(NumericalError) { return try operation() } catch { throw JointStopFailure(.numerical(error)) }
    }
    static func finite(_ value: Double) throws(JointStopFailure) -> Double {
        guard value.isFinite else { throw JointStopFailure(.nonFiniteResult) }; return value
    }
    static func product(_ a: Int, _ b: Int) throws(JointStopFailure) -> Int { try numerical { () throws(NumericalError) in try NumericalWork.product(a,b) } }
    static func sum(_ a: Int, _ b: Int) throws(JointStopFailure) -> Int { try numerical { () throws(NumericalError) in try NumericalWork.sum(a,b) } }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(JointStopFailure) { try numerical { () throws(NumericalError) in try work.chargeOperations(count) } }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(JointStopFailure) { try numerical { () throws(NumericalError) in try work.requireStorage(count) } }
    static func reserved(_ input: JointStopInput) throws(JointStopFailure) -> Int {
        let b=input.model.tree.bodies.count, n=input.state.state.v.count
        return try sum(product(24,try product(b,n)),try sum(product(4,try product(n,n)),try sum(product(1024,b),try sum(product(64,n),256))))
    }
    static func treeCharge(_ input: JointStopInput, _ work: inout NumericalWork) throws(JointStopFailure) {
        try charge(sum(product(8192,input.model.tree.bodies.count),try product(1024,try product(input.model.tree.bodies.count,input.state.state.v.count))),&work)
    }
    static func threshold(_ tolerance: NumericalTolerance, scale: Double) throws(JointStopFailure) -> Double { try finite(tolerance.absolute+tolerance.relative*scale) }
    static func metadata(_ text: String, policy: JointStopPolicy, work: inout NumericalWork) throws(JointStopFailure) {
        var count=0
        for _ in text.utf8 {
            try check(policy)
            guard count < policy.observations.maximumMetadataBytes else { throw JointStopFailure(.capacityExceeded) }
            count+=1; try charge(1,&work)
        }
    }
    static func dot(_ first: [Double], _ second: [Double], work: inout NumericalWork) throws(JointStopFailure) -> Double {
        guard first.count == second.count else { throw JointStopFailure(.invalidShape) }
        try charge(product(2,first.count),&work); var result=0.0
        for i in first.indices {
            guard !Task.isCancelled else { throw JointStopFailure(.cancelled) }
            result=try finite(result+first[i]*second[i])
        }; return result
    }
    static func seeded(_ work: NumericalWork, reserved: Int) throws(JointStopFailure) -> NumericalWork {
        var local=NumericalWork(budget:try numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) })
        try charge(1,&local); return local
    }
    static func reconcile(_ local: NumericalWork, before: NumericalWork, reserved: Int,
                          work: inout NumericalWork) throws(JointStopFailure) {
        let valid=local.budget == before.budget && local.operations >= before.operations && local.iterations >= before.iterations &&
            local.peakScalarStorage >= before.peakScalarStorage && local.operations <= local.budget.arithmeticOperations &&
            local.iterations <= local.budget.iterations && local.peakScalarStorage <= local.budget.scalarStorage
        do throws(NumericalError) { try work.absorb(valid ? local : before,reservedStorage:reserved) }
        catch { throw JointStopFailure(.numerical(error),failedSupplierWorkUnavailable:!valid) }
        guard valid else { throw JointStopFailure(.invalidSupplierLedger,failedSupplierWorkUnavailable:true) }
    }
}
