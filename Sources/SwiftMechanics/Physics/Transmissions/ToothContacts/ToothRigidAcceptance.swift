internal final class ToothRigidAcceptance: Sendable {
    let model: ToothContactModel
    let dynamics: any RigidDynamicsSolving
    init(model: ToothContactModel, dynamics: any RigidDynamicsSolving) { self.model=model; self.dynamics=dynamics }
    @inline(never)
    func evaluate(snapshot: KinematicSnapshot, loads: [BodyWrenchContribution], stored: Double, loss: Double, contactPower: Double, reserved: Int,
                            policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> ToothRigidResult {
        let input: RigidDynamicsInput
        do { input=try RigidDynamicsInput(snapshot:snapshot,velocity:snapshot.coordinateRate,inertias:model.inertias,gravity:nil,bodyWrenches:loads) }
        catch { throw .dynamics(error) }
        let system=try assemble(input,policy:policy,reserved:reserved,work:&work)
        let solved=try ToothArithmetic.numeric(reserved:reserved,policy:policy,work:&work) { (local: inout NumericalWork) throws(DynamicsError) in
            try self.dynamics.forward(system,driveForce:model.driveForce,policy:policy.dynamics,work:&local)
        }
        guard solved.acceleration.count == 2, solved.driveForce == model.driveForce else { throw .invalidSupplierOutput }
        var original=[Double](repeating:0,count:2)
        try ToothArithmetic.numeric(reserved:reserved,policy:policy,work:&work) { (local: inout NumericalWork) throws(DynamicsError) in
            try RigidEquationKernel().originalInertialForce(system,acceleration:solved.acceleration,includeBias:true,into:&original,work:&local)
        }
        try work.charge(128)
        for i in 0..<2 {
            let known: Double
            do { known=try system.forces.total(at:i) } catch { throw .dynamics(error) }
            try ToothArithmetic.close(original[i],known+model.driveForce[i],scale:policy.dynamics.energyScale,policy:policy)
        }
        let energy=try ToothArithmetic.numeric(reserved:reserved,policy:policy,work:&work) { (local: inout NumericalWork) throws(DynamicsError) in
            try RigidEquationKernel().energy(system,acceleration:solved.acceleration,angularMomentumReference:.zero,requireComplete:true,work:&local)
        }
        guard let potential=energy.potentialEnergy else { throw .invalidSupplierOutput }
        try ToothArithmetic.close(potential,stored,scale:policy.dynamics.energyScale,policy:policy)
        let power=try ToothArithmetic.value(contactPower+model.driveForce[0]*input.velocity[0]+model.driveForce[1]*input.velocity[1])
        try ToothArithmetic.close(energy.kineticEnergyRate,power,scale:policy.dynamics.energyScale/policy.dynamics.timeScale,policy:policy)
        try ToothArithmetic.close(system.forces.actualPower,contactPower,scale:policy.dynamics.energyScale/policy.dynamics.timeScale,policy:policy)
        guard energy.time == snapshot.time, energy.frame == model.tree.worldFrame else { throw .invalidSupplierOutput }
        return ToothRigidResult(acceleration:solved.acceleration,contactForce:system.forces.contact,energy:energy)
    }
    @inline(never)
    func assemble(_ input: RigidDynamicsInput, policy: ToothContactPolicy, reserved: Int,
                          work: inout ToothContactWork) throws(ToothContactError) -> RigidDynamicsSystem {
        try ToothArithmetic.check(policy); try work.beginCall()
        let remaining=work.budget.arithmeticOperations-work.operations, storage=work.budget.scalarStorage-reserved
        let numericalBudget: NumericalBudget, loadBudget: LoadBudget
        do { numericalBudget=try NumericalBudget(scalarStorage:storage/2,arithmeticOperations:remaining/2,iterations:work.budget.iterations-work.iterations) }
        catch { throw .numerical(error) }
        do { loadBudget=try LoadBudget(maximumWork:remaining-remaining/2,maximumScalars:storage-storage/2,isCancelled:policy.isCancelled) }
        catch { throw .capacityExceeded }
        var numerical=NumericalWork(budget:numericalBudget), load=LoadWork(budget:loadBudget)
        do { try numerical.chargeOperations(1); try numerical.advanceIteration() } catch {
            try work.charge(numerical.operations,storage:reserved,iterations:numerical.iterations)
            throw .numerical(error)
        }
        do { try load.charge(1) } catch {
            try work.charge(ToothArithmetic.sum(numerical.operations,load.consumed),storage:reserved,iterations:numerical.iterations)
            throw .capacityExceeded
        }
        let result: Result<RigidDynamicsSystem,DynamicsError>
        do { result = .success(try RigidEquationKernel().assemble(input,admission:policy.admission,loadWork:&load,work:&numerical)) }
        catch { result = .failure(error) }
        guard numerical.budget == numericalBudget, numerical.operations >= 1, numerical.iterations >= 1,
              load.budget.maximumWork == loadBudget.maximumWork, load.budget.maximumScalars == loadBudget.maximumScalars,
              load.consumed >= 1 else {
            // Both local operation seeds and the numerical iteration preceded the callback.
            try work.charge(2,storage:reserved,iterations:1)
            throw .invalidSupplierLedger(failedSupplierWorkUnavailable:true)
        }
        try work.charge(ToothArithmetic.sum(numerical.operations,load.consumed),
            storage:ToothArithmetic.sum(reserved,ToothArithmetic.sum(numerical.peakScalarStorage,load.peakScalars)),iterations:numerical.iterations)
        try ToothArithmetic.check(policy)
        switch result { case .success(let system): return system; case .failure(let error): throw .dynamics(error) }
    }
}
