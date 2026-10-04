
/// Index-reduced affine holonomic DAE on explicitly admitted scalar tree coordinates.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class AffineMechanismEquation: SmoothODEEquations, Sendable {
    public let descriptor: ODEDescriptor
    public let model: CompiledMechanicalModel
    public let constraints: QuadraticConstraintSystem
    public let drive: [Double]
    public let policy: MechanismSolvePolicy
    public let admission: DynamicsAdmission
    private let inertias: [RigidBodyInertia]
    private let kernel: any RigidEquationComputing
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
        let sample=try checkedSample(time:time,point:point,work:&work,control:control)
        let n=model.tree.layout.velocityCount
        let state:KinematicState,snapshot:KinematicSnapshot,input:RigidDynamicsInput
        do {
            state=try KinematicState(revision:model.stamp.revision,time:time,q:Array(point[..<n]),v:Array(point[n...]),acceleration:[Double](repeating:0,count:n))
            snapshot=try model.evaluate(model.makeState(state))
            input=try RigidDynamicsInput(snapshot:snapshot,velocity:state.v,inertias:inertias,gravity:nil)
        } catch { throw RuntimeFailure(.invalidState,message:"Actual compiled scalar tree state validation failed.") }
        let reserved=try reserve(work:&work)
        var local=try localWork(work,reserved:reserved),load=try zeroLoadWork()
        let system:RigidDynamicsSystem,assemblyBudget=local.budget
        do throws(DynamicsError) { system=try kernel.assemble(input,admission:admission,loadWork:&load,work:&local) }
        catch {
            try validLocal(local,budget:assemblyBudget);try absorb(local,into:&work,reserved:reserved)
            throw RuntimeFailure(.invalidState,message:"Rigid mass assembly failed; no retry is qualified.",failedSupplierWorkUnavailable:MechanismError.dynamics(error).failedSupplierWorkUnavailable)
        }
        try validLocal(local,budget:assemblyBudget);try absorb(local,into:&work,reserved:reserved)
        local=try localWork(work,reserved:reserved)
        var dynamics=try localWork(work,reserved:reserved),rank=try localWork(work,reserved:reserved),linear=try localWork(work,reserved:reserved)
        let budgets=[local.budget,dynamics.budget,rank.budget,linear.budget]
        var result:ConstrainedMotion?,failure:MechanismError?
        do throws(MechanismError) { result=try solver.acceleration(system,sample:sample,drive:drive,policy:policy,
            work:&local,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear) } catch { failure=error }
        for (ledger,budget) in zip([local,dynamics,rank,linear],budgets) { try validLocal(ledger,budget:budget);try absorb(ledger,into:&work,reserved:reserved) }
        if let failure {
            throw RuntimeFailure(failure.failedSupplierWorkUnavailable ? .invalidOwnerAccess : .invalidState,
                message:failure.failedSupplierWorkUnavailable ? "Mechanism supplier work is unavailable; integration stops without retry." : "Original constrained acceleration failed.",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable)
        }
        guard let result,result.values.count == n,result.values.allSatisfy({$0.isFinite}),result.time == time,
              result.basis == model.tree.layout,result.sourceVelocity == state.v else {
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
    private func checkedSample(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> VelocityConstraintSample {
        try control.beginWorkBlock(units:1)
        let n=model.tree.layout.velocityCount
        guard point.count == 2*n,point.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Invalid affine chart point.") }
        let reserved=try reserve(work:&work);var local=try localWork(work,reserved:reserved)
        let evaluation:ConstraintEvaluation,evaluationBudget=local.budget
        do throws(ConstraintError) { evaluation=try evaluator.evaluate(constraints,position:Array(point[..<n]),velocity:Array(point[n...]),time:time,policy:policy.constraints.evaluation,work:&local) }
        catch {
            try validLocal(local,budget:evaluationBudget);try absorb(local,into:&work,reserved:reserved)
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
    private func reserve(work:inout NumericalWork) throws(RuntimeFailure) -> Int {
        do {
            let n=model.tree.layout.velocityCount,m=constraints.rows.count
            let slots=try NumericalWork.sum(try NumericalWork.product(128,model.tree.bodies.count),try NumericalWork.sum(try NumericalWork.product(4,try NumericalWork.product(n,n)),try NumericalWork.sum(try NumericalWork.product(16,n),try NumericalWork.product(4,try NumericalWork.product(n,m)))))
            try work.requireStorage(slots);try work.chargeOperations(try NumericalWork.sum(try NumericalWork.product(16,n),try NumericalWork.product(8,try NumericalWork.product(n,m))))
            return slots
        } catch { throw RuntimeFailure(.capacityExceeded,message:"Mechanism derivative orchestration budget exhausted.") }
    }
    private func localWork(_ work:NumericalWork,reserved:Int) throws(RuntimeFailure) -> NumericalWork {
        do {
            var local=NumericalWork(budget:try work.remainingBudget(reservedStorage:reserved))
            try local.chargeOperations(1);return local
        }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Mechanism supplier budget exhausted.") }
    }
    private func validLocal(_ local:NumericalWork,budget:NumericalBudget) throws(RuntimeFailure) {
        guard local.budget == budget,local.operations >= 1 else { throw RuntimeFailure(.invalidOwnerAccess,message:"Mechanism supplier replaced/reset its admitted ledger.",failedSupplierWorkUnavailable:true) }
    }
    private func absorb(_ local:NumericalWork,into work:inout NumericalWork,reserved:Int) throws(RuntimeFailure) {
        do { try work.absorb(local,reservedStorage:reserved) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Mechanism aggregate supplier budget exhausted.") }
    }
    private func zeroLoadWork() throws(RuntimeFailure) -> LoadWork {
        do { return LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0)) }
        catch { throw RuntimeFailure(.invalidInput,message:"Invalid zero external-load mapping budget.") }
    }
}
