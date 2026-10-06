@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct ConstrainedImpactRigidSupplier: RigidEquationComputing {
    let base: any RigidEquationComputing
    let receipt: ConstrainedImpactAssemblyReceipt
    @inline(never)
    func assemble(_ input: RigidDynamicsInput, admission: DynamicsAdmission, loadWork: inout LoadWork,
                  work: inout NumericalWork) throws(DynamicsError) -> RigidDynamicsSystem {
        do throws(ConstrainedImpactError) {
            let result = try ConstrainedImpactInvocation.assembly(load:&loadWork,work:&work) { (load: inout LoadWork, numerical: inout NumericalWork) throws(ConstrainedImpactError) in
                do throws(DynamicsError) { return try base.assemble(input,admission:admission,loadWork:&load,work:&numerical) }
                catch { throw ConstrainedImpactError(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
            }
            try ConstrainedImpactSourceBinding.validate(result,input:input,work:&work)
            return result
        } catch {
            receipt.record(error)
            // The operation-local receipt preserves the full error across this frozen protocol boundary.
            if ConstrainedImpactArithmetic.isCancelled(error.reason) { throw .numerical(.cancelled,failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
            throw .supplierLedgerReplaced
        }
    }
    func originalInertialForce(_ system: RigidDynamicsSystem, acceleration: [Double], includeBias: Bool,
                               into output: inout [Double], work: inout NumericalWork) throws(DynamicsError) {
        try base.originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
    }
    func inertialWrench(_ system: RigidDynamicsSystem, body: EntityID, acceleration: [Double], referencePointWorld: Vector3,
                        work: inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        try base.inertialWrench(system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
    }
    func energy(_ system: RigidDynamicsSystem, acceleration: [Double], angularMomentumReference: Vector3, requireComplete: Bool,
                work: inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        try base.energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}
