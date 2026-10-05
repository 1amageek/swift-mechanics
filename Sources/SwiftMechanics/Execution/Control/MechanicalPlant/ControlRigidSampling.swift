internal enum ControlRigidSampling {
    @inline(never)
    static func system(plant:PrismaticControlPlant,time:Double,point:[Double],policy:ControlPolicy,
                       equations:any RigidEquationComputing,work:inout NumericalWork) throws(ControlFailure) -> RigidDynamicsSystem {
        try ControlArithmetic.charge(96,work:&work,policy:policy)
        guard point.count == 2,point.allSatisfy({$0.isFinite}),time.isFinite,
              abs(point[0]) <= policy.maximumPositionMeters,abs(point[1]) <= policy.maximumRateMetersPerSecond else { throw ControlFailure(.invalidInput,phase:"plant-stage") }
        do { try work.requireStorage(512) } catch { throw ControlFailure(.numerical(error),phase:"plant-stage") }
        let state:KinematicState,snapshot:KinematicSnapshot
        do { state=try KinematicState(revision:plant.model.stamp.revision,time:time,q:[point[0]],v:[point[1]],acceleration:[0]);snapshot=try plant.model.evaluate(plant.model.makeState(state)) }
        catch { throw ControlFailure(.invalidInput,phase:"compiled-stage") }
        let input:RigidDynamicsInput
        do { input=try RigidDynamicsInput(snapshot:snapshot,velocity:[point[1]],inertias:plant.inertias,gravity:nil) }
        catch { throw ControlFailure(.dynamics(error),phase:"plant-input") }
        var local=try nested(work,reserved:512),load:LoadWork
        do { load=LoadWork(budget:try LoadBudget(maximumWork:1,maximumScalars:0,isCancelled:policy.isCancelled));try load.charge(1) } catch { throw ControlFailure(.dynamics(.loads(error)),phase:"plant-input") }
        let before=local,loadBefore=load
        var result:RigidDynamicsSystem?,failure:DynamicsError?
        do { result=try equations.assemble(input,admission:policy.admission,loadWork:&load,work:&local) } catch { failure=error }
        let loadValid=load.budget.maximumWork == loadBefore.budget.maximumWork && load.budget.maximumScalars == loadBefore.budget.maximumScalars && load.consumed >= loadBefore.consumed && load.peakScalars >= loadBefore.peakScalars
        try reconcile(local,before:before,work:&work,reserved:512,auxiliaryValid:loadValid)
        if let failure { throw ControlFailure(.dynamics(failure),phase:"assembly",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        guard let result,result.scalarStorage >= 0,result.scalarStorage <= work.budget.scalarStorage-512,result.velocityCount == 1,result.massMatrix.count == 1,result.inertialBias.count == 1,
              ControlArithmetic.agrees(result.massMatrix[0],plant.movingMass,policy.agreement),ControlArithmetic.agrees(result.inertialBias[0],0,policy.agreement),
              result.input.velocity == input.velocity,result.input.inertias == input.inertias,result.input.snapshot.time == time else { throw ControlFailure(.invalidSupplierOutput,phase:"assembly") }
        try ControlArithmetic.check(policy)
        return result
    }
    @inline(never)
    static func solve(_ system:RigidDynamicsSystem,drive:Double,inverseAcceleration:Double?,plant:PrismaticControlPlant,
                      dynamics:any RigidDynamicsSolving,policy:ControlPolicy,work:inout NumericalWork) throws(ControlFailure) -> DynamicsSolution {
        var local=try nested(work,reserved:system.scalarStorage+512)
        let before=local
        var result:DynamicsSolution?,failure:DynamicsError?
        do {
            if let inverseAcceleration { result=try dynamics.inverse(system,acceleration:[inverseAcceleration],policy:policy.dynamics,work:&local) }
            else { result=try dynamics.forward(system,driveForce:[drive],policy:policy.dynamics,work:&local) }
        } catch { failure=error }
        try reconcile(local,before:before,work:&work,reserved:system.scalarStorage+512)
        if let failure { throw ControlFailure(.dynamics(failure),phase:"dynamics",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        guard let result,result.acceleration.count == 1,result.driveForce.count == 1,result.acceleration[0].isFinite,result.driveForce[0].isFinite else { throw ControlFailure(.invalidSupplierOutput,phase:"dynamics") }
        let acceleration=inverseAcceleration ?? result.acceleration[0]
        guard ControlArithmetic.agrees(result.acceleration[0],acceleration,policy.agreement),
              ControlArithmetic.agrees(result.driveForce[0],plant.movingMass*acceleration,policy.agreement) else { throw ControlFailure(.originalEvidenceRejected,phase:"dynamics") }
        return result
    }
    @inline(never)
    static func evidence(_ system:RigidDynamicsSystem,acceleration:Double,force:Double,plant:PrismaticControlPlant,
                         equations:any RigidEquationComputing,policy:ControlPolicy,work:inout NumericalWork) throws(ControlFailure) -> ControlMechanicalSample {
        var local=try nested(work,reserved:system.scalarStorage+512)
        let before=local
        var original=[Double](repeating:.nan,count:1),energy:MechanicalEnergy?,failure:DynamicsError?
        do {
            try equations.originalInertialForce(system,acceleration:[acceleration],includeBias:true,into:&original,work:&local)
            energy=try equations.energy(system,acceleration:[acceleration],angularMomentumReference:.zero,requireComplete:true,work:&local)
        } catch { failure=error }
        try reconcile(local,before:before,work:&work,reserved:system.scalarStorage+512)
        if let failure { throw ControlFailure(.dynamics(failure),phase:"physical-evidence",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        guard let energy,original.count == 1,original[0].isFinite,energy.time == system.input.snapshot.time,
              energy.frame == plant.model.descriptor.worldFrame,
              ControlArithmetic.agrees(original[0],plant.movingMass*acceleration,policy.agreement),ControlArithmetic.agrees(original[0],force,policy.agreement),
              ControlArithmetic.agrees(energy.kineticEnergy,0.5*plant.movingMass*system.input.velocity[0]*system.input.velocity[0],policy.agreement),
              ControlArithmetic.agrees(energy.kineticEnergyRate,force*system.input.velocity[0],policy.agreement),
              energy.potentialEnergy == 0,energy.dissipatedPower == 0 else { throw ControlFailure(.originalEvidenceRejected,phase:"physical-evidence") }
        return ControlMechanicalSample(system:system,acceleration:acceleration,kineticEnergy:energy.kineticEnergy,forceResidual:original[0]-force)
    }
    static func nested(_ work:NumericalWork,reserved:Int) throws(ControlFailure) -> NumericalWork {
        do { var local=NumericalWork(budget:try work.remainingBudget(reservedStorage:reserved));try local.chargeOperations(1);return local }
        catch { throw ControlFailure(.numerical(error),phase:"nested-work") }
    }
    static func reconcile(_ local:NumericalWork,before:NumericalWork,work:inout NumericalWork,reserved:Int,auxiliaryValid:Bool = true) throws(ControlFailure) {
        let valid=local.budget == before.budget && local.operations >= before.operations && local.iterations >= before.iterations && local.peakScalarStorage >= before.peakScalarStorage
        do { try work.absorb(valid ? local:before,reservedStorage:reserved) } catch { throw ControlFailure(.numerical(error),phase:"nested-work",failedSupplierWorkUnavailable:!valid || !auxiliaryValid) }
        guard valid,auxiliaryValid else { throw ControlFailure(.invalidSupplierLedger,phase:"nested-work",failedSupplierWorkUnavailable:true) }
    }
}
