extension RigidEquationKernel {
    @inline(never)
    public func partitionedPower(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], knownCoordinates: [Int],
                                 drive: [Double], geometricReaction: [Double], policy: DynamicsSolvePolicy,
                                 work: inout NumericalWork) throws(DynamicsError) -> PartitionedMechanicalPower {
        let n=system.velocityCount,k=knownCoordinates.count
        guard n <= system.admission.capacity.maximumVelocities,k <= n,acceleration.count == n,drive.count == n,
              geometricReaction.count == n,policy.coordinateScales.count == n,policy.energyScale.isFinite,policy.energyScale > 0 else { throw .invalidShape }
        guard !Task.isCancelled,!system.admission.isCancelled() else { throw .cancelled }
        try DynamicsArithmetic.storage(DynamicsArithmetic.sum(system.scalarStorage,DynamicsArithmetic.product(16,n)),&work)
        try DynamicsArithmetic.operations(DynamicsArithmetic.sum(DynamicsArithmetic.product(n,n),DynamicsArithmetic.product(8,n)),&work)
        for i in 0..<n {
            guard acceleration[i].isFinite,drive[i].isFinite,geometricReaction[i].isFinite,
                  policy.coordinateScales[i].isFinite,policy.coordinateScales[i] > 0 else { throw .invalidInput }
        }
        for i in knownCoordinates.indices {
            guard knownCoordinates[i] >= 0,knownCoordinates[i] < n,!knownCoordinates[..<i].contains(knownCoordinates[i]),
                  drive[knownCoordinates[i]] == 0 else { throw .invalidInput }
        }
        let energy=try energy(system,acceleration:acceleration,angularMomentumReference:.zero,requireComplete:false,work:&work)
        var original=[Double](repeating:0,count:n)
        try originalInertialForce(system,acceleration:acceleration,includeBias:true,into:&original,work:&work)
        return try completePartition(system,acceleration:acceleration,knownCoordinates:knownCoordinates,drive:drive,
            geometricReaction:geometricReaction,policy:policy,energy:energy,original:original,work:&work)
    }
    @inline(never)
    private func completePartition(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],knownCoordinates:[Int],drive:[Double],
                                   geometricReaction:[Double],policy:DynamicsSolvePolicy,energy:MechanicalEnergy,original:[Double],
                                   work:inout NumericalWork) throws(DynamicsError) -> PartitionedMechanicalPower {
        var efforts=[Double](repeating:0,count:knownCoordinates.count)
        var known=0.0,dynamic=0.0,actuation=0.0,reaction=0.0,driven=0.0,loads=0.0,residual=0.0,scale=0.0
        for i in original.indices {
            guard !Task.isCancelled,!system.admission.isCancelled() else { throw .cancelled }
            try DynamicsArithmetic.operations(DynamicsArithmetic.sum(24,knownCoordinates.count),&work)
            let velocity=system.input.velocity[i],load=try system.forces.total(at:i)
            if let index=knownCoordinates.firstIndex(of:i) {
                efforts[index]=try DynamicsArithmetic.finite(original[i]-load-geometricReaction[i])
                known=try DynamicsArithmetic.finite(known+original[i]*velocity)
                actuation=try DynamicsArithmetic.finite(actuation+efforts[index]*velocity)
            } else {
                dynamic=try DynamicsArithmetic.finite(dynamic+original[i]*velocity)
                let applied=try DynamicsArithmetic.finite(drive[i]+load+geometricReaction[i])
                residual=max(residual,abs(original[i]-applied)*policy.coordinateScales[i]/policy.energyScale)
                scale=max(scale,max(abs(original[i]),abs(applied))*policy.coordinateScales[i]/policy.energyScale)
            }
            reaction=try DynamicsArithmetic.finite(reaction+geometricReaction[i]*velocity)
            driven=try DynamicsArithmetic.finite(driven+drive[i]*velocity)
            loads=try DynamicsArithmetic.finite(loads+load*velocity)
        }
        let threshold:Double
        do throws(NumericalError) { threshold=try policy.linearTolerance.threshold(scale:scale) }
        catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
        guard residual <= threshold else { throw .physicalResidualRejected(value:residual,threshold:threshold) }
        let powerResidual=abs(known+dynamic-energy.requiredVirtualPower)
        let powerThreshold:Double
        do throws(NumericalError) { powerThreshold=try policy.linearTolerance.threshold(scale:max(abs(known)+abs(dynamic),abs(energy.requiredVirtualPower))) }
        catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
        guard powerResidual.isFinite,powerResidual <= powerThreshold else { throw .physicalResidualRejected(value:powerResidual,threshold:powerThreshold) }
        guard !Task.isCancelled,!system.admission.isCancelled() else { throw .cancelled }
        return PartitionedMechanicalPower(system:system,acceleration:acceleration,knownCoordinates:knownCoordinates,drive:drive,
            geometricReaction:geometricReaction,energy:energy,original:original,effort:efforts,known:known,dynamic:dynamic,
            actuation:actuation,reaction:reaction,drivePower:driven,loads:loads)
    }
}
