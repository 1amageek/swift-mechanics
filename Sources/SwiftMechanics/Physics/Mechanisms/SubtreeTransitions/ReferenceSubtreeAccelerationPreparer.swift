public struct ReferenceSubtreeAccelerationPreparer: SubtreeAccelerationPreparing {
    private let solver: any RigidDynamicsSolving
    public init(solver: any RigidDynamicsSolving = DenseRigidDynamics()) { self.solver=solver }
    @inline(never)
    public func prepare(_ release: SubtreeRelease, gravity: AffineGravity?, bodyWrenches: [BodyWrenchContribution],
                        generalizedForces: [GeneralizedForceContribution], drive: [Double], admission: DynamicsAdmission,
                        policy: DynamicsSolvePolicy, work: inout NumericalWork, loadWork: inout LoadWork) throws(TopologyReleaseFailure) -> ReconciledSubtreeRelease {
        guard !Task.isCancelled, !admission.isCancelled() else { throw .cancelled }
        guard drive.count == release.target.tree.layout.velocityCount,
              drive.allSatisfy({ $0.isFinite }), policy.coordinateScales.count == drive.count else { throw .invalidInput }
        try TopologyArithmetic.numerical { () throws(NumericalError) in
            try work.requireStorage(try NumericalWork.sum(try NumericalWork.product(release.target.tree.bodies.count,128),try NumericalWork.product(drive.count,8)))
        }
        let snapshot: KinematicSnapshot
        do throws(CompilationFailure) { snapshot = try release.target.evaluate(release.target.makeState(release.incomingPhysical)) }
        catch { throw .compilation(error) }
        var inertias: [RigidBodyInertia] = []
        for body in snapshot.bodies {
            guard let record=release.target.descriptor.bodies.first(where: { $0.id == body.body }),
                  case .spatial(let spatial)=record, let inertia=spatial.inertia else { throw .unsupportedDomain }
            do throws(DynamicsError) { inertias.append(try RigidBodyInertia(body:spatial.id,frame:spatial.frame,properties:inertia.properties)) }
            catch { throw .dynamics(error) }
        }
        let input: RigidDynamicsInput
        do throws(DynamicsError) {
            input=try RigidDynamicsInput(snapshot:snapshot,velocity:release.incomingPhysical.v,inertias:inertias,
                gravity:gravity,bodyWrenches:bodyWrenches,generalizedForces:generalizedForces)
        } catch { throw .dynamics(error) }
        let kernel=RigidEquationKernel()
        // This concrete producer binds the complete caller target force input; an injected solve cannot change it.
        let system=try TopologyArithmetic.dynamics(&work) { (ledger: inout NumericalWork) throws(DynamicsError) in
            try kernel.assemble(input,admission:admission,loadWork:&loadWork,work:&ledger)
        }
        let solution=try TopologyArithmetic.dynamics(&work) { (ledger: inout NumericalWork) throws(DynamicsError) in
            try solver.forward(system,driveForce:drive,policy:policy,work:&ledger)
        }
        guard solution.acceleration.count == drive.count, solution.acceleration.allSatisfy({ $0.isFinite }),
              solution.driveForce == drive, solution.work == work else { throw .originalAcceptance }
        var original=[Double](repeating:0,count:drive.count)
        try TopologyArithmetic.dynamics(&work) { (ledger: inout NumericalWork) throws(DynamicsError) in
            try kernel.originalInertialForce(system,acceleration:solution.acceleration,includeBias:true,into:&original,work:&ledger)
        }
        var residual=0.0, scale=0.0
        for i in original.indices {
            try TopologyArithmetic.charge(6,&work)
            let known: Double
            do throws(DynamicsError) { known = try system.forces.total(at:i) } catch { throw .dynamics(error) }
            let expected=(drive[i]+known)*policy.coordinateScales[i]/policy.energyScale
            let actual=original[i]*policy.coordinateScales[i]/policy.energyScale
            guard expected.isFinite,actual.isFinite else { throw .originalAcceptance }
            residual=max(residual,abs(actual-expected)); scale=max(scale,max(abs(actual),abs(expected)))
        }
        let threshold=try TopologyArithmetic.numerical { () throws(NumericalError) in try policy.linearTolerance.threshold(scale:scale) }
        guard residual <= threshold else { throw .originalAcceptance }
        let physical: KinematicState
        do { physical=try KinematicState(revision:release.target.stamp.revision,time:release.incomingPhysical.time,
            q:release.incomingPhysical.q,v:release.incomingPhysical.v,acceleration:solution.acceleration) }
        catch { throw .invalidInput }
        do throws(CompilationFailure) { _=try release.target.makeState(physical) } catch { throw .compilation(error) }
        guard !Task.isCancelled,!admission.isCancelled() else { throw .cancelled }
        return ReconciledSubtreeRelease(admission:_SubtreeAccelerationAdmission(release:release,physical:physical,system:system,drive:drive,residual:residual))
    }
}

internal struct _SubtreeAccelerationAdmission: Sendable {
    let release: SubtreeRelease; let physical: KinematicState; let system: RigidDynamicsSystem
    let drive: [Double]; let residual: Double
    fileprivate init(release:SubtreeRelease,physical:KinematicState,system:RigidDynamicsSystem,drive:[Double],residual:Double) {
        self.release=release; self.physical=physical; self.system=system; self.drive=drive; self.residual=residual
    }
}
