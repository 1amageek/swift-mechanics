internal struct JointStopMassInvocation: Sendable {
    let mass: any PhysicalRigidDynamicsSolving
    @inline(never)
    func inverse(_ system: PhysicalRigidDynamicsSystem, rhs: [Double], prepared: PreparedJointStop,
                 policy: JointStopPolicy, work: inout NumericalWork) throws(JointStopFailure) -> [Double] {
        let a=JointStopArithmetic.self, reserved=try a.reserved(prepared.input), n=system.velocityCount
        try a.check(policy)
        var local=try a.seeded(work,reserved:reserved); let before=local
        var result: PhysicalDynamicsSolution?, failure: DynamicsError?
        do throws(DynamicsError) { result=try mass.inverseMassProduct(system,rightHandSide:rhs,policy:policy.mass,work:&local) }
        catch { failure=error }
        try a.reconcile(local,before:before,reserved:reserved,work:&work)
        if let failure { throw JointStopFailure(.dynamics(failure),failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        try a.charge(a.product(8,n),&work)
        guard let result, result.system === system, result.work == local, result.driveForce == rhs,
              result.acceleration.count == n, result.acceleration.allSatisfy({$0.isFinite}), result.originalPhysicalResidual.isAccepted,
              result.originalPhysicalResidual.equation == .massOnly, let diagnostics=result.linearDiagnostics,
              diagnostics.capability == policy.mass.capability, diagnostics.factorization == .cholesky,
              diagnostics.numericalRank == n, diagnostics.originalResidual.isAccepted else { throw JointStopFailure(.invalidSupplierOutput) }
        var original=[Double](repeating:0,count:n)
        do throws(DynamicsError) { try RigidEquationKernel().originalInertialForce(system,acceleration:result.acceleration,includeBias:false,into:&original,work:&work) }
        catch { throw JointStopFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        var residual=0.0, scale=0.0
        for i in original.indices {
            try a.check(policy)
            let conversion=policy.mass.coordinateScales[i]/policy.mass.energyScale
            let actual=try a.finite(original[i]*conversion), expected=try a.finite(rhs[i]*conversion)
            residual=max(residual,abs(try a.finite(actual-expected))); scale=max(scale,max(abs(actual),abs(expected)))
        }
        let limit=try a.numerical { () throws(NumericalError) in try policy.mass.linearTolerance.threshold(scale:scale) }
        guard residual <= limit else { throw JointStopFailure(.momentumRejected(value:residual,threshold:limit)) }
        try a.check(policy); return result.acceleration
    }
    @inline(never)
    static func assemble(_ prepared: PreparedJointStop, source: ObservationSource, policy: JointStopPolicy,
                         work: inout NumericalWork, loadWork: inout LoadWork) throws(JointStopFailure) -> PhysicalRigidDynamicsSystem {
        try JointStopArithmetic.check(policy)
        do throws(DynamicsError) {
            let input=try RigidDynamicsInput(snapshot:source.snapshot,velocity:source.state.state.v,inertias:prepared.input.inertias,gravity:nil)
            return try RigidEquationKernel().assemble(PhysicalRigidDynamicsInput(spatial:input),admission:policy.admission,loadWork:&loadWork,work:&work)
        } catch { throw JointStopFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
    }
}
