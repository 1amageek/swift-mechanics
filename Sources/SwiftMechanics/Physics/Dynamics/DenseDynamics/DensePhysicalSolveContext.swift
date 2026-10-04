/// Only immutable admitted source and witness handles cross solve phases.
internal final class DensePhysicalSolveContext: Sendable {
    let system:PhysicalRigidDynamicsSystem
    let equations:DenseEquationSupplier
    let guardedSuppliers:Bool
    init(system:PhysicalRigidDynamicsSystem,equations:DenseEquationSupplier,guardedSuppliers:Bool) {
        self.system=system;self.equations=equations;self.guardedSuppliers=guardedSuppliers
    }
    var velocityCount:Int { system.velocityCount }
    var massMatrix:[Double] { system.massMatrix }
    var inertialBias:[Double] { system.inertialBias }
    var forces:ForceBudget { system.forces }
    var scalarStorage:Int { system.scalarStorage }
    var admission:DynamicsAdmission { system.admission }
    @inline(never)
    func original(acceleration:[Double],includeBias:Bool,into output:inout [Double],work:inout NumericalWork) throws(DynamicsError) {
        if !guardedSuppliers {
            try equations.original(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
            return
        }
        guard !admission.isCancelled(),!Task.isCancelled else { throw .cancelled }
        try DynamicsArithmetic.operations(1,&work)
        let reserved=work.peakScalarStorage
        var local:NumericalWork
        do {
            local=NumericalWork(budget:try work.remainingBudget(reservedStorage:reserved))
            try local.chargeOperations(1)
        } catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
        let before=local
        var failure:DynamicsError?
        do throws(DynamicsError) { try equations.original(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&local) }
        catch { failure=error }
        guard local.budget == before.budget,local.operations >= before.operations,local.iterations >= before.iterations,
              local.peakScalarStorage >= before.peakScalarStorage,local.operations <= local.budget.arithmeticOperations,
              local.iterations <= local.budget.iterations,local.peakScalarStorage <= local.budget.scalarStorage else {
            do { try work.absorb(before,reservedStorage:reserved) }
            catch { throw .numerical(error,failedSupplierWorkUnavailable:true) }
            throw .supplierLedgerReplaced
        }
        do { try work.absorb(local,reservedStorage:reserved) }
        catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
        if let failure { throw failure }
        guard !admission.isCancelled(),!Task.isCancelled else { throw .cancelled }
        guard output.count == velocityCount,output.allSatisfy({$0.isFinite}) else { throw .invalidShape }
    }
}
