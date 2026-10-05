internal struct FrictionalImpulseSupplier: Sendable {
    let mass: any PhysicalRigidDynamicsSolving
    let linear: any LinearSolving<Double>

    @inline(never)
    func inverse(_ system: PhysicalRigidDynamicsSystem, rhs: [Double], policy: FrictionalImpulsePolicy,
                 reserved: Int, work: inout NumericalWork) throws(FrictionalImpulseFailure) -> [Double] {
        let a=FrictionalImpulseArithmetic.self
        try a.check(policy)
        var local=NumericalWork(budget:try a.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) })
        try a.charge(1,&local); let before=local
        var result: PhysicalDynamicsSolution?, failure: DynamicsError?
        do throws(DynamicsError) { result=try mass.inverseMassProduct(system,rightHandSide:rhs,policy:policy.mass,work:&local) } catch { failure=error }
        let valid=local.budget == before.budget && local.operations >= before.operations && local.iterations >= before.iterations &&
            local.peakScalarStorage >= before.peakScalarStorage && local.operations <= local.budget.arithmeticOperations &&
            local.iterations <= local.budget.iterations && local.peakScalarStorage <= local.budget.scalarStorage
        try a.numerical { () throws(NumericalError) in try work.absorb(valid ? local : before,reservedStorage:reserved) }
        guard valid else { throw FrictionalImpulseFailure(.invalidSupplierLedger,failedSupplierWorkUnavailable:true) }
        if let failure { throw FrictionalImpulseFailure(.dynamics(failure),failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        try a.charge(a.product(8,system.velocityCount),&work)
        guard let result, result.system === system, result.work == local, result.driveForce == rhs,
              result.acceleration.count == system.velocityCount, result.acceleration.allSatisfy({$0.isFinite}),
              result.originalPhysicalResidual.equation == .massOnly, result.originalPhysicalResidual.isAccepted,
              let diagnostics=result.linearDiagnostics, diagnostics.capability == policy.mass.capability,
              diagnostics.factorization == .cholesky, diagnostics.numericalRank == system.velocityCount,
              diagnostics.originalResidual.isAccepted else { throw FrictionalImpulseFailure(.invalidSupplierOutput) }
        var original=[Double](repeating:0,count:system.velocityCount)
        do { try RigidEquationKernel().originalInertialForce(system,acceleration:result.acceleration,includeBias:false,into:&original,work:&work) }
        catch { throw FrictionalImpulseFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        var residual=0.0, scale=0.0
        for i in original.indices {
            let conversion=policy.mass.coordinateScales[i]/policy.mass.energyScale
            let actual=try a.finite(original[i]*conversion), expected=try a.finite(rhs[i]*conversion)
            residual=max(residual,abs(try a.finite(actual-expected))); scale=max(scale,max(abs(actual),abs(expected)))
        }
        let limit=try a.numerical { () throws(NumericalError) in try policy.mass.linearTolerance.threshold(scale:scale) }
        guard residual <= limit else { throw FrictionalImpulseFailure(.momentumRejected(value:residual,threshold:limit)) }
        try a.check(policy); return result.acceleration
    }

    @inline(never)
    func tangent(_ values: [Double], rhs: [Double], policy: FrictionalImpulsePolicy,
                 reserved: Int, work: inout NumericalWork) throws(FrictionalImpulseFailure) -> [Double] {
        let a=FrictionalImpulseArithmetic.self
        try a.check(policy); try a.charge(1,&work)
        let capability=LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky)
        let matrix=try a.numerical { () throws(NumericalError) in try DenseMatrix(rows:2,columns:2,values:values) }
        let budget=try a.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        let result: LinearSolution<Double>
        do { result=try linear.solve(matrix,rightHandSide:rhs,capability:capability,tolerance:policy.tangentTolerance,budget:budget) }
        catch { throw FrictionalImpulseFailure(.numerical(error),failedSupplierWorkUnavailable:true) }
        let local=result.diagnostics.work
        guard local.budget == budget, local.operations >= 2, local.iterations >= 2,
              local.operations <= budget.arithmeticOperations, local.iterations <= budget.iterations,
              local.peakScalarStorage <= budget.scalarStorage else { throw FrictionalImpulseFailure(.invalidSupplierLedger,failedSupplierWorkUnavailable:true) }
        try a.numerical { () throws(NumericalError) in try work.absorb(local,reservedStorage:reserved) }
        guard result.values.count == 2, result.values.allSatisfy({$0.isFinite}), result.diagnostics.capability == capability,
              result.diagnostics.factorization == .cholesky, result.diagnostics.numericalRank == 2 else { throw FrictionalImpulseFailure(.invalidSupplierOutput) }
        try a.charge(20,&work); var residual=0.0, scale=0.0
        for i in 0..<2 {
            let image=try a.finite(values[2*i]*result.values[0]+values[2*i+1]*result.values[1])
            residual=max(residual,abs(try a.finite(image-rhs[i]))); scale=max(scale,max(abs(image),abs(rhs[i])))
        }
        let limit=try a.numerical { () throws(NumericalError) in try policy.tangentTolerance.threshold(scale:scale) }
        guard residual <= limit else { throw FrictionalImpulseFailure(.coulombRejected(value:residual,threshold:limit)) }
        try a.check(policy); return result.values
    }
}
