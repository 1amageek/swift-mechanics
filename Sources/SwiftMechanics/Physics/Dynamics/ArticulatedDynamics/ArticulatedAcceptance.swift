internal enum ArticulatedAcceptance {
    @inline(never)
    static func publish(_ input: RigidDynamicsInput, acceleration: [Double], rhs: [Double], operation: ArticulatedDynamicsOperation,
                        recursiveOperations: Int, policy: ArticulatedDynamicsPolicy, loadWork: inout LoadWork,
                        work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> ArticulatedDynamicsResult {
        try ArticulatedArithmetic.check(policy)
        let n = rhs.count, reserved = try ArticulatedArithmetic.product(2,n)
        var local: NumericalWork
        do { local = NumericalWork(budget:try work.remainingBudget(reservedStorage:reserved)); try local.chargeOperations(1) }
        catch { throw ArticulatedDynamicsFailure(.numerical(error)) }
        let before = local
        let kernel = RigidEquationKernel()
        var system: PhysicalRigidDynamicsSystem?, failure: DynamicsError?
        // This original dense assembly follows the candidate; its M never enters ABA recovery.
        do { system = try kernel.assemble(PhysicalRigidDynamicsInput(spatial:input),admission:policy.admission,loadWork:&loadWork,work:&local) }
        catch { failure = error }
        let ledgerValid = local.budget == before.budget && local.operations >= before.operations && local.iterations >= before.iterations &&
            local.peakScalarStorage >= before.peakScalarStorage && local.operations <= local.budget.arithmeticOperations &&
            local.iterations <= local.budget.iterations && local.peakScalarStorage <= local.budget.scalarStorage
        do { try work.absorb(ledgerValid ? local : before,reservedStorage:reserved) }
        catch { throw ArticulatedDynamicsFailure(.numerical(error),failedSupplierWorkUnavailable:!ledgerValid) }
        guard ledgerValid else { throw ArticulatedDynamicsFailure(.dynamics(.supplierLedgerReplaced),failedSupplierWorkUnavailable:true) }
        if let failure { throw ArticulatedDynamicsFailure(.dynamics(failure),failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        guard let system else { throw ArticulatedDynamicsFailure(.sourceMismatch) }
        try ArticulatedArithmetic.storage(try ArticulatedArithmetic.sum(system.scalarStorage,try ArticulatedArithmetic.product(5,n)),&work)
        let includeBias: Bool
        switch operation { case .forward: includeBias = true; case .inverseMass: includeBias = false }
        var original = [Double](repeating:0,count:n)
        do { try kernel.originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&original,work:&work) }
        catch { throw ArticulatedDynamicsFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        var residual = 0.0, reference = 0.0
        for i in 0..<n {
            try ArticulatedArithmetic.check(policy); try ArticulatedArithmetic.charge(8,&work)
            let known: Double
            do {
                if includeBias { known = try system.forces.total(at:i) }
                else { known = 0 }
            }
            catch { throw ArticulatedDynamicsFailure(.dynamics(error)) }
            let scale = try ArticulatedArithmetic.finite(policy.coordinateScales[i]/policy.energyScale)
            let expected = try ArticulatedArithmetic.finite((rhs[i]+known)*scale)
            let actual = try ArticulatedArithmetic.finite(original[i]*scale)
            residual = max(residual,abs(try ArticulatedArithmetic.finite(actual-expected)))
            reference = max(reference,max(abs(actual),abs(expected)))
        }
        let threshold = try ArticulatedArithmetic.threshold(policy.originalResidualTolerance,scale:reference,work:&work)
        guard residual <= threshold else { throw ArticulatedDynamicsFailure(.originalResidualRejected(value:residual,threshold:threshold)) }
        var fullOriginal = original
        if !includeBias {
            do { try kernel.originalInertialForce(system,acceleration:acceleration,includeBias:true,into:&fullOriginal,work:&work) }
            catch { throw ArticulatedDynamicsFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        }
        let energy: MechanicalEnergy
        do { energy = try kernel.energy(system,acceleration:acceleration,angularMomentumReference:policy.angularMomentumReferenceWorld,
            requireComplete:policy.requireCompleteEnergy,work:&work) }
        catch { throw ArticulatedDynamicsFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        let originalPower = try ArticulatedArithmetic.dot(fullOriginal,input.velocity,work:&work)
        try ArticulatedArithmetic.charge(4,&work)
        var powerResidual = max(abs(try ArticulatedArithmetic.finite(energy.requiredVirtualPower-originalPower)),
            abs(try ArticulatedArithmetic.finite(energy.kineticEnergyRate-energy.requiredVirtualPower-energy.requiredPrescribedPower)))
        var powerScale = max(abs(originalPower),max(abs(energy.kineticEnergyRate),abs(energy.requiredVirtualPower)))
        if includeBias {
            let drivePower = try ArticulatedArithmetic.dot(rhs,input.velocity,work:&work)
            try ArticulatedArithmetic.charge(2,&work)
            let expectedPower = try ArticulatedArithmetic.finite(drivePower+system.forces.virtualPower)
            powerResidual = max(powerResidual,abs(try ArticulatedArithmetic.finite(energy.requiredVirtualPower-expectedPower)))
            powerScale = max(powerScale,abs(expectedPower))
        }
        let powerThreshold = try ArticulatedArithmetic.threshold(policy.powerTolerance,scale:powerScale,work:&work)
        guard powerResidual <= powerThreshold else { throw ArticulatedDynamicsFailure(.originalPowerRejected(value:powerResidual,threshold:powerThreshold)) }
        try ArticulatedArithmetic.check(policy)
        let evidence = ArticulatedDynamicsResidual(originalGeneralizedInertialForce:original,normalizedInfinityNorm:residual,
            referenceScale:reference,threshold:threshold,originalVirtualPowerResidualWatts:powerResidual)
        return ArticulatedDynamicsResult(operation:operation,originalSystem:system,acceleration:acceleration,rightHandSide:rhs,
            originalResidual:evidence,energy:energy,recursiveOperations:recursiveOperations,work:work,loadWork:loadWork)
    }
}
