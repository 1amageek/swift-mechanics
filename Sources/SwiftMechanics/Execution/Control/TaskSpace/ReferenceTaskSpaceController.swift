public struct ReferenceTaskSpaceController: TaskSpaceControlling, Sendable {
    private let physical: TaskSpacePhysicalInvocation
    private let linear: TaskSpaceLinearInvocation
    public init(dynamics: any PhysicalRigidDynamicsSolving = DenseRigidDynamics(physicalEquations:RigidEquationKernel()),
                linearSolver: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) {
        physical = TaskSpacePhysicalInvocation(dynamics:dynamics); linear = TaskSpaceLinearInvocation(solver:linearSolver)
    }
    @inline(never)
    public func evaluate(_ request: TaskSpaceRequest, policy: TaskSpacePolicy,
                         work: inout NumericalWork) throws(TaskSpaceFailure) -> TaskSpaceResult {
        let reserved = try admit(request,policy:policy,work:&work)
        switch request.command {
        case .pointMotion(let task): return try motion(request,task:task,policy:policy,reserved:reserved,work:&work)
        case .bodyOriginWrench(let command): return try wrench(request,command:command,policy:policy,reserved:reserved,work:&work)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Hybrid force/motion compatibility requires an original
        // constrained physical force subspace and reaction authority. The public hybrid request
        // fails until that allocation and simultaneous motion/force evidence exist.
        case .hybrid: throw TaskSpaceFailure(.incompatibleForceMotion)
        // FIXME(INCOMPLETE_IMPLEMENTATION): The constrained-contact force request has no admitted
        // contact/reaction supplier in this controller. Original constrained force semantics and
        // source-specific reaction evidence are required before successful command publication.
        case .constrainedContactForce: throw TaskSpaceFailure(.unsupportedDomain)
        }
    }
    private func admit(_ request: TaskSpaceRequest, policy: TaskSpacePolicy,
                       work: inout NumericalWork) throws(TaskSpaceFailure) -> Int {
        let system = request.system, snapshot = system.input.snapshot, tree = snapshot.tree, n = system.velocityCount
        try TaskSpaceArithmetic.check(system,policy)
        guard n > 0, n <= policy.maximumVelocities, tree.bodies.count <= policy.maximumBodies else {
            throw TaskSpaceFailure(.capacityExceeded)
        }
        guard request.expectedTime.isFinite, request.expectedTime == snapshot.time, request.expectedRevision == tree.revision else {
            throw TaskSpaceFailure(.staleSource)
        }
        guard request.worldFrame == tree.worldFrame else { throw TaskSpaceFailure(.frameMismatch) }
        guard n == tree.layout.velocityCount, policy.dynamics.coordinateScales.count == n else { throw TaskSpaceFailure(.invalidShape) }
        let square = try TaskSpaceArithmetic.product(n,n)
        let scratch = try TaskSpaceArithmetic.sum(try TaskSpaceArithmetic.product(10,square),
            try TaskSpaceArithmetic.sum(try TaskSpaceArithmetic.product(100,n),300))
        let reserved = try TaskSpaceArithmetic.sum(system.scalarStorage,scratch)
        try TaskSpaceArithmetic.storage(reserved,&work)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Floating/manifold or prescribed-anchor operational
        // control is outside this Euclidean fixed-tree path. Original tangent transport and
        // drift-owned force/motion evidence are required before these domains can succeed.
        guard tree.rootBase == .fixed, tree.layout.positionCount == n else { throw TaskSpaceFailure(.unsupportedDomain) }
        for joint in tree.joints {
            try TaskSpaceArithmetic.check(system,policy); try TaskSpaceArithmetic.charge(4,&work)
            guard joint.manifold.positionCount == joint.manifold.velocityCount else { throw TaskSpaceFailure(.unsupportedDomain) }
            for anchor in [joint.parentAnchor,joint.childAnchor] {
                if case .prescribed = anchor.placement { throw TaskSpaceFailure(.unsupportedDomain) }
            }
        }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Unknown constraints/contact are not represented by
        // a free physical system. This current command path refuses even supplied reaction-channel
        // loads until a constrained mass/force authority can certify the selected control law.
        for load in system.input.bodyWrenches {
            try TaskSpaceArithmetic.charge(1,&work)
            if load.channel == .constraint || load.channel == .contact { throw TaskSpaceFailure(.unsupportedDomain) }
        }
        for load in system.input.generalizedForces {
            try TaskSpaceArithmetic.charge(1,&work)
            if load.channel == .constraint || load.channel == .contact { throw TaskSpaceFailure(.unsupportedDomain) }
        }
        do { try policy.dynamics.capability.validate(for:Double.self,algorithms:[.cholesky]) }
        catch { throw TaskSpaceFailure(.numerical(error)) }
        return reserved
    }
    @inline(never)
    private func motion(_ request: TaskSpaceRequest, task: TaskSpaceMotion, policy: TaskSpacePolicy,
                        reserved: Int, work: inout NumericalWork) throws(TaskSpaceFailure) -> TaskSpaceResult {
        let system = request.system
        let solved = try TaskSpaceMotionSolver(physical:physical,linear:linear).solve(task,system:system,policy:policy,reserved:reserved,work:&work)
        let inverse = try physical.call(.inverse,system:system,values:solved.total,policy:policy,reserved:reserved,work:&work)
        let response = try physical.call(.forward,system:system,values:inverse.driveForce,policy:policy,reserved:reserved,work:&work)
        for i in response.acceleration.indices {
            try TaskSpaceArithmetic.check(system,policy); try TaskSpaceArithmetic.charge(7,&work)
            let conversion = try TaskSpaceArithmetic.finite(policy.dynamics.timeScale*policy.dynamics.timeScale/policy.dynamics.coordinateScales[i])
            let actual = try TaskSpaceArithmetic.finite(response.acceleration[i]*conversion)
            let expected = try TaskSpaceArithmetic.finite(solved.total[i]*conversion)
            let residual = abs(try TaskSpaceArithmetic.finite(actual-expected))
            let threshold = try TaskSpaceArithmetic.threshold(policy.replayTolerance,scale:max(abs(actual),abs(expected)),work:&work)
            guard residual <= threshold else { throw TaskSpaceFailure(.generalizedReplayRejected(value:residual,threshold:threshold)) }
        }
        try TaskSpaceArithmetic.charge(try TaskSpaceArithmetic.product(60,system.velocityCount),&work)
        let actualImage: Vector3, primaryImage: Vector3, secondaryImage: Vector3, virtualVelocity: Vector3
        do {
            actualImage = try solved.jacobian.applying(response.acceleration[...]).adding(solved.pointMotion.accelerationBias)
            primaryImage = try solved.jacobian.applying(solved.primary[...]).adding(solved.pointMotion.accelerationBias)
            secondaryImage = try solved.jacobian.applying(solved.secondary[...])
            virtualVelocity = try solved.jacobian.applying(system.input.velocity[...])
        } catch let error as CoreError { throw TaskSpaceFailure(.core(error)) }
        catch let error as JointError { throw TaskSpaceFailure(.joints(error)) }
        catch { throw TaskSpaceFailure(.invalidSupplierOutput) }
        var achieved = [Double](repeating:0,count:task.axes.count), residual = achieved, primaryResidual = achieved, leak = achieved
        for row in task.axes.indices {
            try TaskSpaceArithmetic.check(system,policy); try TaskSpaceArithmetic.charge(4,&work)
            let desired = task.accelerationMetersPerSecondSquared[row]
            achieved[row] = task.axes[row].component(actualImage)
            residual[row] = try TaskSpaceArithmetic.finite(achieved[row]-desired)
            primaryResidual[row] = try TaskSpaceArithmetic.finite(task.axes[row].component(primaryImage)-desired)
            leak[row] = task.axes[row].component(secondaryImage)
            let threshold = try TaskSpaceArithmetic.threshold(policy.taskAccelerationTolerance,scale:max(abs(desired),abs(achieved[row])),work:&work)
            guard abs(residual[row]) <= threshold else { throw TaskSpaceFailure(.taskResidualRejected(value:abs(residual[row]),threshold:threshold)) }
            let primaryThreshold = try TaskSpaceArithmetic.threshold(policy.taskAccelerationTolerance,scale:max(abs(desired),abs(task.axes[row].component(primaryImage))),work:&work)
            try TaskSpaceArithmetic.charge(1,&work)
            let defectMismatch = abs(try TaskSpaceArithmetic.finite(primaryResidual[row]+solved.regularizationDefect[row]))
            guard abs(primaryResidual[row]) <= primaryThreshold, defectMismatch <= primaryThreshold else {
                throw TaskSpaceFailure(.taskResidualRejected(value:max(abs(primaryResidual[row]),defectMismatch),threshold:primaryThreshold))
            }
            let leakThreshold = try TaskSpaceArithmetic.threshold(policy.secondaryLeakTolerance,scale:max(abs(desired),abs(task.axes[row].component(solved.pointMotion.accelerationBias))),work:&work)
            guard abs(leak[row]) <= leakThreshold else { throw TaskSpaceFailure(.secondaryLeakRejected(value:abs(leak[row]),threshold:leakThreshold)) }
            try TaskSpaceArithmetic.charge(1,&work)
            let secondaryDefectMismatch = abs(try TaskSpaceArithmetic.finite(leak[row]-solved.secondaryRegularizationDefect[row]))
            guard secondaryDefectMismatch <= leakThreshold else { throw TaskSpaceFailure(.secondaryLeakRejected(value:secondaryDefectMismatch,threshold:leakThreshold)) }
        }
        try TaskSpaceArithmetic.charge(30,&work)
        let dualVirtual = try TaskSpaceArithmetic.core { () throws(CoreError) in try solved.pointForce.dot(virtualVelocity) }
        let dualActual = try TaskSpaceArithmetic.core { () throws(CoreError) in try solved.pointForce.dot(solved.pointMotion.velocity) }
        let dualDrift = try TaskSpaceArithmetic.core { () throws(CoreError) in try solved.pointForce.dot(solved.jacobian.prescribedDriftVelocity) }
        let dualLoads: [Double]
        do { dualLoads = try solved.jacobian.transposed(against:solved.pointForce) }
        catch let error as CoreError { throw TaskSpaceFailure(.core(error)) }
        catch { throw TaskSpaceFailure(.invalidSupplierOutput) }
        let dualGeneralized = try TaskSpaceArithmetic.dot(dualLoads,system.input.velocity,work:&work)
        let powerResidual = try powerCheck(virtual:dualVirtual,actual:dualActual,drift:dualDrift,generalized:dualGeneralized,policy:policy,work:&work)
        let drivePower = try TaskSpaceArithmetic.dot(inverse.driveForce,system.input.velocity,work:&work)
        try TaskSpaceArithmetic.check(system,policy)
        let diagnostics = TaskSpaceDiagnostics(taskRank:solved.rank,damping:solved.damping,usesExactDynamicallyConsistentInverse:solved.damping == 0,
            primaryAcceleration:solved.primary,projectedSecondaryAcceleration:solved.secondary,achievedTaskAcceleration:achieved,
            primaryTaskResidual:primaryResidual,secondaryTaskLeak:leak,taskResidual:residual,regularizationDefect:solved.regularizationDefect,
            secondaryRegularizationDefect:solved.secondaryRegularizationDefect,pointTaskDualForceNewtons:solved.pointForce,
            generalizedDrivePowerWatts:drivePower,taskDualVirtualPowerWatts:dualVirtual,taskDualActualPowerWatts:dualActual,
            taskDualPrescribedPowerWatts:dualDrift,virtualPowerResidualWatts:powerResidual,work:work)
        return TaskSpaceResult(request:request,generalizedEffort:inverse.driveForce,physicalResponse:response,diagnostics:diagnostics)
    }
    @inline(never)
    private func wrench(_ request: TaskSpaceRequest, command: TaskSpaceWrench, policy: TaskSpacePolicy,
                        reserved: Int, work: inout NumericalWork) throws(TaskSpaceFailure) -> TaskSpaceResult {
        let system = request.system, snapshot = system.input.snapshot
        // FIXME(INCOMPLETE_IMPLEMENTATION): Original planar force control cannot infer transverse
        // support reactions. This body-origin command rejects off-plane wrench components until
        // a separately admitted support model and actual reaction evidence exist.
        if system.input.dimension == .planar, command.wrench.force.z != 0 || command.wrench.torque.x != 0 || command.wrench.torque.y != 0 {
            throw TaskSpaceFailure(.unsupportedDomain)
        }
        let jacobian: KinematicJacobian, body: BodyKinematics, effort: [Double], virtualMotion: SpatialMotion
        try TaskSpaceArithmetic.charge(try TaskSpaceArithmetic.product(96,system.velocityCount),&work)
        do {
            body = try snapshot.body(command.body)
            guard command.referencePointWorld == body.motion.pose.translation else { throw TaskSpaceFailure(.referencePointMismatch) }
            jacobian = try KinematicJacobianCalculator().geometric(body:command.body,snapshot:snapshot)
            effort = try jacobian.transposed(against:command.wrench)
            virtualMotion = try jacobian.applying(system.input.velocity[...])
        } catch let error as TaskSpaceFailure { throw error }
        catch let error as JointError { throw TaskSpaceFailure(.joints(error)) }
        catch let error as CoreError { throw TaskSpaceFailure(.core(error)) }
        catch { throw TaskSpaceFailure(.invalidSupplierOutput) }
        let response = try physical.call(.forward,system:system,values:effort,policy:policy,reserved:reserved,work:&work)
        try TaskSpaceArithmetic.charge(40,&work)
        let virtual = try TaskSpaceArithmetic.core { () throws(CoreError) in try command.wrench.power(against:virtualMotion) }
        let actual = try TaskSpaceArithmetic.core { () throws(CoreError) in try command.wrench.power(against:body.motion.velocity) }
        let drift = try TaskSpaceArithmetic.core { () throws(CoreError) in try command.wrench.power(against:jacobian.prescribedDrift) }
        let generalized = try TaskSpaceArithmetic.dot(effort,system.input.velocity,work:&work)
        let powerResidual = try powerCheck(virtual:virtual,actual:actual,drift:drift,generalized:generalized,policy:policy,work:&work)
        try TaskSpaceArithmetic.check(system,policy)
        let diagnostics = TaskSpaceDiagnostics(taskRank:nil,damping:0,usesExactDynamicallyConsistentInverse:false,
            primaryAcceleration:[],projectedSecondaryAcceleration:[],achievedTaskAcceleration:[],primaryTaskResidual:[],secondaryTaskLeak:[],
            taskResidual:[],regularizationDefect:[],secondaryRegularizationDefect:[],pointTaskDualForceNewtons:nil,
            generalizedDrivePowerWatts:generalized,taskDualVirtualPowerWatts:virtual,
            taskDualActualPowerWatts:actual,taskDualPrescribedPowerWatts:drift,virtualPowerResidualWatts:powerResidual,work:work)
        return TaskSpaceResult(request:request,generalizedEffort:effort,physicalResponse:response,diagnostics:diagnostics)
    }
    private func powerCheck(virtual: Double, actual: Double, drift: Double, generalized: Double,
                            policy: TaskSpacePolicy, work: inout NumericalWork) throws(TaskSpaceFailure) -> Double {
        try TaskSpaceArithmetic.charge(3,&work)
        let residual = max(abs(try TaskSpaceArithmetic.finite(virtual-generalized)),abs(try TaskSpaceArithmetic.finite(actual-virtual-drift)))
        let threshold = try TaskSpaceArithmetic.threshold(policy.powerTolerance,scale:max(abs(actual),max(abs(virtual),abs(generalized))),work:&work)
        guard residual <= threshold else { throw TaskSpaceFailure(.powerResidualRejected(value:residual,threshold:threshold)) }
        return residual
    }
}
