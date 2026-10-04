
/// Index-reduced affine holonomic DAE on explicitly admitted scalar tree coordinates.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class AffineMechanismEquation: SmoothODEEquations, Sendable {
    public let descriptor: ODEDescriptor
    public let model: CompiledMechanicalModel
    public let constraints: QuadraticConstraintSystem
    public let drive: [Double]
    public let policy: MechanismSolvePolicy
    public let admission: DynamicsAdmission
    internal let inertias: [RigidBodyInertia]
    internal let kernel: any RigidEquationComputing
    private let evaluator: any ConstraintEvaluating
    private let solver: any ConstrainedMechanismSolving
    public init(identity: String, model: CompiledMechanicalModel, constraints: QuadraticConstraintSystem,
                drive: [Double], policy: MechanismSolvePolicy, admission: DynamicsAdmission,
                maximumIdentityBytes: Int, kernel: any RigidEquationComputing = RigidEquationKernel(),
                evaluator: any ConstraintEvaluating = QuadraticConstraintEvaluator(),
                solver: any ConstrainedMechanismSolving = MassWeightedMechanismSolver()) throws(MechanismError) {
        try AffineMechanismChart.bounded(identity,maximum:maximumIdentityBytes)
        try AffineMechanismChart.bounded(model.stamp.identity,maximum:maximumIdentityBytes)
        let n=model.tree.layout.velocityCount
        // FIXME(INCOMPLETE_IMPLEMENTATION): This callable equation constructor admits fixed-root scalar affine index-reduced charts only. General nonlinear closed-loop DAE and floating manifold evolution require original position/velocity consistency and chart publication proofs before successful construction.
        guard n > 0, n <= policy.maximumCoordinates, model.tree.rootBase == .fixed,
              model.descriptor.rootAuthority == .fixed, model.tree.layout.positionCount == n,
              constraints.layout.revision == model.stamp.revision, constraints.layout.scales.count == n,
              constraints.layout.scales == policy.dynamics.coordinateScales,
              constraints.layout.timeScale == policy.dynamics.timeScale, drive.count == n,
              drive.allSatisfy({ $0.isFinite }), constraints.rows.count <= policy.maximumRows else { throw .unsupportedChart }
        for entry in model.tree.layout.joints {
            guard entry.positions.count == 1, entry.velocities.count == 1,entry.positions.start == entry.velocities.start,
                  let joint=model.descriptor.joints.first(where:{$0.record.id == entry.joint}),joint.authority == .dynamicState,
                  joint.record.manifold.kind == .revolute || joint.record.manifold.kind == .prismatic,
                  constraints.layout.dimensions[entry.velocities.start] == (joint.record.manifold.kind == .revolute ? .angle : .length) else { throw .unsupportedChart }
            for anchor in [joint.record.parentAnchor,joint.record.childAnchor] {
                if case .prescribed=anchor.placement { throw .unsupportedChart }
            }
        }
        let square=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(n,n) }
        for i in 0..<n {
            guard constraints.minimumPosition[i].isFinite,constraints.maximumPosition[i].isFinite,
                  constraints.minimumPosition[i] <= constraints.maximumPosition[i] else { throw .invalidInput }
        }
        for index in constraints.rows.indices {
            let row=constraints.rows[index]
            guard row.constant.isFinite,row.timeLinear.isFinite,row.linear.allSatisfy({$0.isFinite}),
                  !constraints.rows[..<index].contains(where:{$0.id == row.id}) else { throw .invalidInput }
            guard row.linear.count == n,row.mixedTime.count == n,row.hessian.count == square,
                  row.hessian.allSatisfy({$0 == 0}),row.mixedTime.allSatisfy({$0 == 0}),row.timeQuadratic == 0 else { throw .unsupportedChart }
        }
        var bound:[RigidBodyInertia]=[]; bound.reserveCapacity(model.tree.bodies.count)
        for body in model.tree.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.id}) else { throw .staleBinding }
            // This initial equation path requires actual spatial inertias, not a fabricated planar embedding.
            guard case .spatial(let spatial)=record,let representation=spatial.inertia else { throw .unsupportedChart }
            do throws(DynamicsError) { bound.append(try RigidBodyInertia(body:body.id,frame:body.frame,properties:representation.properties)) }
            catch { throw .dynamics(error) }
        }
        var dimensions=constraints.layout.dimensions
        for dimension in constraints.layout.dimensions {
            dimensions.append(PhysicalDimension(length:dimension.length,time:-1,angle:dimension.angle))
        }
        let chart=try AffineMechanismChart.signature(constraints,drive:drive,tolerance:policy.originalTolerance,maximumBytes:maximumIdentityBytes)
        do { descriptor=try ODEDescriptor(identity:identity,chart:chart,model:model.stamp,dimensions:dimensions,
            maximumIdentityBytes:maximumIdentityBytes,maximumCoordinates:try NumericalWork.product(2,policy.maximumCoordinates)) }
        catch { throw .invalidInput }
        self.model=model;self.constraints=constraints;self.drive=drive;self.policy=policy;self.admission=admission;inertias=bound
        self.kernel=kernel;self.evaluator=evaluator;self.solver=solver
    }
    public func validate(model: CompiledMechanicalModel) throws(RuntimeFailure) {
        guard model.stamp == self.model.stamp,model.descriptor == self.model.descriptor,model.tree.layout == self.model.tree.layout else {
            throw RuntimeFailure(.incompatibleModel,message:"Affine mechanism equation model/layout differs.")
        }
    }
    public func read(_ state: KinematicState, into point: inout [Double]) throws(RuntimeFailure) {
        let n=model.tree.layout.velocityCount
        guard state.revision == model.stamp.revision,state.q.count == n,state.v.count == n,point.count == 2*n else {
            throw RuntimeFailure(.invalidState,message:"Scalar mechanism physical chart mismatch.")
        }
        for i in 0..<n { point[i]=state.q[i];point[n+i]=state.v[i] }
    }
    public func read(_ trial: RuntimeTrial, into point: inout [Double]) throws(RuntimeFailure) {
        let n=model.tree.layout.velocityCount
        guard point.count == 2*n else { throw RuntimeFailure(.invalidState,message:"Scalar mechanism output chart mismatch.") }
        for i in 0..<n { point[i]=try trial.position(at:i);point[n+i]=try trial.velocity(at:i) }
    }
    public func prepare(trial: inout RuntimeTrial, work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) {
        _=try reserve(work:&work)
        var point=[Double](repeating:0,count:descriptor.dimensions.count)
        try read(trial,into:&point)
        _=try checkedSample(time:trial.timeSeconds,point:point,work:&work,control:control)
    }
    @inline(never)
    public func derivative(time: Double, point: [Double], into output: inout [Double], work: inout NumericalWork,
                           control: RuntimeStepControl) throws(RuntimeFailure) {
        guard output.count == point.count else { throw RuntimeFailure(.invalidState,message:"Derivative output layout mismatch.") }
        let result=try motion(time:time,point:point,work:&work,control:control)
        let n=model.tree.layout.velocityCount
        for i in 0..<n { output[i]=point[n+i];output[n+i]=result.values[i] }
    }
    @inline(never)
    public func motion(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> ConstrainedMotion {
        let rows=try motionRows(time:time,point:point,work:&work,control:control)
        let input=try motionInput(time:time,point:point)
        let system=try motionAssembly(input,work:&work)
        let result=try motionSolve(system,rows:rows,work:&work)
        return try associateMotion(result,input:input,time:time)
    }
    @inline(never)
    private func motionRows(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> AffineMotionRows {
        AffineMotionRows(try checkedSample(time:time,point:point,work:&work,control:control))
    }
    @inline(never)
    private func motionInput(time:Double,point:[Double]) throws(RuntimeFailure) -> AffineMotionInput {
        let physical=try motionPhysical(time:time,point:point)
        let snapshot=try motionSnapshot(physical)
        do throws(DynamicsError) { return AffineMotionInput(try RigidDynamicsInput(snapshot:snapshot.value,velocity:physical.value.v,inertias:inertias,gravity:nil)) }
        catch { throw RuntimeFailure(.invalidState,message:"Actual compiled scalar tree state validation failed.") }
    }
    @inline(never)
    private func motionPhysical(time:Double,point:[Double]) throws(RuntimeFailure) -> AffineMotionPhysical {
        let n=model.tree.layout.velocityCount
        do { return AffineMotionPhysical(try KinematicState(revision:model.stamp.revision,time:time,q:Array(point[..<n]),v:Array(point[n...]),acceleration:[Double](repeating:0,count:n))) }
        catch { throw RuntimeFailure(.invalidState,message:"Actual compiled scalar tree state validation failed.") }
    }
    @inline(never)
    internal func motionSnapshot(_ physical:AffineMotionPhysical) throws(RuntimeFailure) -> AffineMotionSnapshot {
        let state=try motionCompiledState(physical)
        do throws(CompilationFailure) { return AffineMotionSnapshot(try model.evaluate(state)) }
        catch { throw RuntimeFailure(.invalidState,message:"Actual compiled scalar tree state validation failed.") }
    }
    @inline(never)
    private func motionCompiledState(_ physical:AffineMotionPhysical) throws(RuntimeFailure) -> CompiledKinematicState {
        do throws(CompilationFailure) { return try model.makeState(physical.value) }
        catch { throw RuntimeFailure(.invalidState,message:"Actual compiled scalar tree state validation failed.") }
    }
    @inline(never)
    private func motionAssembly(_ input:AffineMotionInput,work:inout NumericalWork) throws(RuntimeFailure) -> AffineMotionSystem {
        let reserved=try reserve(work:&work)
        var local=try localWork(work,reserved:reserved),load=try zeroLoadWork()
        let budget=local.budget
        var output:AffineMotionSystem?,failure:DynamicsError?
        do throws(DynamicsError) { output=AffineMotionSystem(try kernel.assemble(input.value,admission:admission,loadWork:&load,work:&local),reserved:reserved) }
        catch { failure=error }
        try validLocal(local,budget:budget);try absorb(local,into:&work,reserved:reserved)
        if let failure { throw RuntimeFailure(.invalidState,message:"Rigid mass assembly failed; no retry is qualified.",failedSupplierWorkUnavailable:MechanismError.dynamics(failure).failedSupplierWorkUnavailable) }
        guard let output else { throw RuntimeFailure(.invalidState,message:"Rigid mass assembly has no result.") };return output
    }
    @inline(never)
    internal func motionSolve(_ system:AffineMotionSystem,rows:AffineMotionRows,work:inout NumericalWork,partitionWork:Bool = false,driveOverride:[Double]? = nil) throws(RuntimeFailure) -> ConstrainedMotion {
        let invocation=try admitMotionSolve(system,work:work,partitionWork:partitionWork,drive:driveOverride ?? drive)
        let outcome=invokeMotionSolve(system,rows:rows,invocation:invocation)
        return try finishMotionSolve(invocation,outcome:outcome,work:&work)
    }
    @inline(never)
    private func admitMotionSolve(_ system:AffineMotionSystem,work:NumericalWork,partitionWork:Bool,drive:[Double]) throws(RuntimeFailure) -> AffineSolveInvocation {
        let reserved=system.reserved,partitions=partitionWork ? 4 : 1
        let local=try localWork(work,reserved:reserved,partitions:partitions),dynamics=try localWork(work,reserved:reserved,partitions:partitions),rank=try localWork(work,reserved:reserved,partitions:partitions),linear=try localWork(work,reserved:reserved,partitions:partitions)
        return AffineSolveInvocation(reserved:reserved,partitionWork:partitionWork,drive:drive,local:local,dynamics:dynamics,rank:rank,linear:linear)
    }
    @inline(never)
    private func invokeMotionSolve(_ system:AffineMotionSystem,rows:AffineMotionRows,invocation:AffineSolveInvocation) -> AffineSolveOutcome {
        var local=invocation.local,dynamics=invocation.dynamics,rank=invocation.rank,linear=invocation.linear
        do throws(MechanismError) {
            let result=try solver.acceleration(system.value,sample:rows.value,drive:invocation.drive,policy:policy,
                work:&local,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear)
            return AffineSolveOutcome(result:result,local:local,dynamics:dynamics,rank:rank,linear:linear)
        } catch { return AffineSolveOutcome(failure:error,local:local,dynamics:dynamics,rank:rank,linear:linear) }
    }
    @inline(never)
    private func finishMotionSolve(_ invocation:AffineSolveInvocation,outcome:AffineSolveOutcome,work:inout NumericalWork) throws(RuntimeFailure) -> ConstrainedMotion {
        try validLocal(outcome.local,budget:invocation.local.budget);try absorb(outcome.local,into:&work,reserved:invocation.reserved)
        try validLocal(outcome.dynamics,budget:invocation.dynamics.budget);try absorb(outcome.dynamics,into:&work,reserved:invocation.reserved)
        try validLocal(outcome.rank,budget:invocation.rank.budget);try absorb(outcome.rank,into:&work,reserved:invocation.reserved)
        try validLocal(outcome.linear,budget:invocation.linear.budget);try absorb(outcome.linear,into:&work,reserved:invocation.reserved)
        if let failure=outcome.failure {
            if invocation.partitionWork {
                switch failure {
                case .cancelled,.numerical(.cancelled,_),.constraint(.cancelled),.dynamics(.cancelled),.dynamics(.loads(.cancelled)),.dynamics(.numerical(.cancelled,_)):
                    throw RuntimeFailure(.cancelled,message:"Loaded original constrained acceleration cancelled.",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable)
                default:break
                }
            }
            throw RuntimeFailure(failure.failedSupplierWorkUnavailable ? .invalidOwnerAccess : .invalidState,
                message:failure.failedSupplierWorkUnavailable ? "Mechanism supplier work is unavailable; integration stops without retry." : "Original constrained acceleration failed.",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable)
        }
        guard let result=outcome.result else { throw RuntimeFailure(.invalidState,message:"Constrained acceleration has no result.") };return result
    }
    @inline(never)
    private func associateMotion(_ result:ConstrainedMotion,input:AffineMotionInput,time:Double) throws(RuntimeFailure) -> ConstrainedMotion {
        let n=model.tree.layout.velocityCount
        guard result.values.count == n,result.values.allSatisfy({$0.isFinite}),result.time == time,
              result.basis == model.tree.layout,result.sourceVelocity == input.value.velocity else {
            throw RuntimeFailure(.invalidState,message:"Constrained motion source/output shape differs from actual model stage.")
        }
        return result
    }
    public func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) {
        let n=model.tree.layout.velocityCount
        guard point.count == 2*n,derivative.count == point.count,point.allSatisfy({$0.isFinite}),derivative.allSatisfy({$0.isFinite}) else {
            throw RuntimeFailure(.invalidState,message:"Nonfinite/mismatched endpoint.")
        }
        // Endpoint is published exactly. The required derivative already validated every original row.
        for i in 0..<n {
            guard derivative[i] == point[n+i] else { throw RuntimeFailure(.invalidState,message:"Scalar endpoint qdot differs from velocity.") }
            try trial.setPosition(point[i],at:i);try trial.setVelocity(point[n+i],at:i);try trial.setAcceleration(derivative[n+i],at:i)
        }
        try trial.setTime(time)
    }
    @inline(never)
    internal func checkedSample(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> VelocityConstraintSample {
        if let control { try control.beginWorkBlock(units:1) }
        let n=model.tree.layout.velocityCount
        guard point.count == 2*n,point.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Invalid affine chart point.") }
        let reserved=try reserve(work:&work);var local=try localWork(work,reserved:reserved)
        let evaluation:ConstraintEvaluation,evaluationBudget=local.budget
        do throws(ConstraintError) { evaluation=try evaluator.evaluate(constraints,position:Array(point[..<n]),velocity:Array(point[n...]),time:time,policy:policy.constraints.evaluation,work:&local) }
        catch {
            try validLocal(local,budget:evaluationBudget);try absorb(local,into:&work,reserved:reserved)
            if case nil=control,case .cancelled=error { throw RuntimeFailure(.cancelled,message:"Loaded original row evaluation cancelled.",failedSupplierWorkUnavailable:MechanismError.constraint(error).failedSupplierWorkUnavailable) }
            throw RuntimeFailure(.invalidState,message:"Original affine row evaluation failed.",failedSupplierWorkUnavailable:MechanismError.constraint(error).failedSupplierWorkUnavailable)
        }
        try validLocal(local,budget:evaluationBudget);try absorb(local,into:&work,reserved:reserved)
        guard evaluation.values.count == constraints.rows.count,evaluation.rowIDs == constraints.rows.map({$0.id}),
              evaluation.jacobian.count == n*constraints.rows.count,evaluation.timeDerivative.count == constraints.rows.count,
              evaluation.accelerationBias.count == constraints.rows.count else { throw RuntimeFailure(.invalidState,message:"Constraint supplier changed retained original row shape.") }
        for row in evaluation.values.indices {
            let original=constraints.rows[row]
            var position=original.constant+original.timeLinear*time/constraints.layout.timeScale
            var velocity=original.timeLinear
            for i in 0..<n {
                position+=original.linear[i]*point[i]/constraints.layout.scales[i]
                velocity+=original.linear[i]*point[n+i]*constraints.layout.timeScale/constraints.layout.scales[i]
                guard evaluation.jacobian[row*n+i] == original.linear[i] else { throw RuntimeFailure(.invalidState,message:"Supplier changed the original affine gradient.") }
            }
            guard evaluation.values[row].isFinite,position.isFinite,velocity.isFinite,
                  abs(evaluation.values[row]-position) <= policy.originalTolerance,
                  evaluation.timeDerivative[row] == original.timeLinear,evaluation.accelerationBias[row] == 0,
                  abs(position) <= policy.originalTolerance,abs(velocity) <= policy.originalTolerance else {
                throw RuntimeFailure(.invalidState,message:"Affine DAE stage violates original position/velocity rows; no endpoint projection.")
            }
        }
        return VelocityConstraintSample(layout:constraints.layout,holonomic:evaluation)
    }
    internal func reserve(work:inout NumericalWork) throws(RuntimeFailure) -> Int {
        do {
            let n=model.tree.layout.velocityCount,m=constraints.rows.count
            let slots=try NumericalWork.sum(try NumericalWork.product(128,model.tree.bodies.count),try NumericalWork.sum(try NumericalWork.product(4,try NumericalWork.product(n,n)),try NumericalWork.sum(try NumericalWork.product(16,n),try NumericalWork.product(4,try NumericalWork.product(n,m)))))
            try work.requireStorage(slots);try work.chargeOperations(try NumericalWork.sum(try NumericalWork.product(16,n),try NumericalWork.product(8,try NumericalWork.product(n,m))))
            return slots
        } catch { throw RuntimeFailure(.capacityExceeded,message:"Mechanism derivative orchestration budget exhausted.") }
    }
    internal func localWork(_ work:NumericalWork,reserved:Int,partitions:Int = 1) throws(RuntimeFailure) -> NumericalWork {
        do {
            let remaining=try work.remainingBudget(reservedStorage:reserved)
            var local=NumericalWork(budget:try NumericalBudget(scalarStorage:remaining.scalarStorage,arithmeticOperations:remaining.arithmeticOperations/partitions,iterations:remaining.iterations/partitions))
            try local.chargeOperations(1);return local
        }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Mechanism supplier budget exhausted.") }
    }
    internal func validLocal(_ local:NumericalWork,budget:NumericalBudget) throws(RuntimeFailure) {
        guard local.budget == budget,local.operations >= 1 else { throw RuntimeFailure(.invalidOwnerAccess,message:"Mechanism supplier replaced/reset its admitted ledger.",failedSupplierWorkUnavailable:true) }
    }
    internal func absorb(_ local:NumericalWork,into work:inout NumericalWork,reserved:Int) throws(RuntimeFailure) {
        do { try work.absorb(local,reservedStorage:reserved) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Mechanism aggregate supplier budget exhausted.") }
    }
    private func zeroLoadWork() throws(RuntimeFailure) -> LoadWork {
        do { return LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0)) }
        catch { throw RuntimeFailure(.invalidInput,message:"Invalid zero external-load mapping budget.") }
    }
}
