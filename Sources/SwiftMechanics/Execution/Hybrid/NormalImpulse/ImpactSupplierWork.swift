
internal enum ImpactSupplierWork {
    static func inverse(_ mass: any RigidDynamicsSolving, system: RigidDynamicsSystem, rhs: [Double], policy: DynamicsSolvePolicy,
                        reserved: Int, work: inout NumericalWork) throws(HybridError) -> DynamicsSolution {
        let budget=try ImpactArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        var nested=NumericalWork(budget:budget)
        let result: DynamicsSolution
        do { result=try mass.inverseMassProduct(system,rightHandSide:rhs,policy:policy,work:&nested) }
        catch {
            guard nested.budget == budget else { throw .invalidOwnerAccess }
            try ImpactArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:reserved) }; throw .dynamics(error)
        }
        guard nested.budget == budget, result.work == nested else { throw .invalidOwnerAccess }
        try ImpactArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:reserved) }
        return result
    }
    static func action(_ equations: any RigidEquationComputing, system: RigidDynamicsSystem, values: [Double], into output: inout [Double],
                       reserved: Int, work: inout NumericalWork) throws(HybridError) {
        let budget=try ImpactArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        var nested=NumericalWork(budget:budget)
        do { try equations.originalInertialForce(system,acceleration:values,includeBias:false,into:&output,work:&nested) }
        catch {
            guard nested.budget == budget else { throw .invalidOwnerAccess }
            try ImpactArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:reserved) }; throw .dynamics(error)
        }
        guard nested.budget == budget else { throw .invalidOwnerAccess }
        try ImpactArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:reserved) }
    }
}
