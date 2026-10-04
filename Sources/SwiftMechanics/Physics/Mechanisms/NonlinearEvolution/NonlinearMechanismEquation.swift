/// Actual compiled-tree holonomic evolution with independent position and velocity charts.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class NonlinearMechanismEquation: ProjectedMechanismEquations, Sendable {
    public let descriptor: ODEDescriptor
    public let model: CompiledMechanicalModel
    public let constraints: QuadraticConstraintSystem
    public let velocityLayout: ConstraintCoordinateLayout
    public let drive: [Double]
    public let policy: MechanismSolvePolicy
    public let projection: NonlinearMechanismProjectionPolicy
    private let physical:NonlinearPhysicalEngine
    private let quaternionBlocks: [(position:Int,velocity:Int)]
    private let evaluator: any ConstraintEvaluating
    private let ranker: any ConstraintRankAnalyzing
    private let linear: any LinearSolving<Double>
    public init(identity:String, model:CompiledMechanicalModel, constraints:QuadraticConstraintSystem,
                velocityLayout:ConstraintCoordinateLayout, drive:[Double], policy:MechanismSolvePolicy,
                projection:NonlinearMechanismProjectionPolicy, admission:DynamicsAdmission, maximumIdentityBytes:Int,
                kernel:any RigidEquationComputing = RigidEquationKernel(), evaluator:any ConstraintEvaluating = QuadraticConstraintEvaluator(),
                solver:any ConstrainedMechanismSolving = MassWeightedMechanismSolver(),
                ranker:any ConstraintRankAnalyzing = WeightedConstraintAssembler(), linear:any LinearSolving<Double> = ReferenceLinearSolver<Double>()) throws(MechanismError) {
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount
        guard p > 0,n > 0,p <= projection.position.evaluation.maximumCoordinates,n <= policy.maximumCoordinates,
              constraints.rows.count <= policy.maximumRows,constraints.layout.scales.count == p,velocityLayout.scales.count == n,
              drive.count == n,drive.allSatisfy({$0.isFinite}),model.tree.bodies.count <= admission.capacity.maximumBodies,constraints.layout.revision == model.stamp.revision,
              velocityLayout.revision == model.stamp.revision,velocityLayout.scales == policy.dynamics.coordinateScales,
              velocityLayout.timeScale == policy.dynamics.timeScale,constraints.layout.timeScale == velocityLayout.timeScale,
              projection.position.diagonalMetric.count == p,policy.constraints.diagonalMetric.count == n else { throw .invalidShape }
        guard identity.utf8.count <= maximumIdentityBytes,model.stamp.identity.utf8.count <= maximumIdentityBytes else { throw .capacityExceeded }
        for scale in constraints.layout.scales+velocityLayout.scales { guard scale.isFinite,scale > 0 else { throw .invalidInput } }
        // FIXME(INCOMPLETE_IMPLEMENTATION): The equation has no prescribed-anchor sample provider. Models with prescribed anchors must supply time-coherent pose/velocity/acceleration data and original force/work acceptance before successful admission.
        for joint in model.descriptor.joints {
            for anchor in [joint.record.parentAnchor,joint.record.childAnchor] {
                if case .prescribed = anchor.placement { throw .unsupportedChart }
            }
        }
        for joint in model.descriptor.joints { guard joint.authority == .dynamicState else { throw .unsupportedChart } }
        switch model.tree.rootBase {
        case .fixed: guard model.descriptor.rootAuthority == .fixed else { throw .unsupportedChart }
        default: guard model.descriptor.rootAuthority == .dynamicState else { throw .unsupportedChart }
        }
        func require(_ position:Int,_ velocity:Int,_ qDimensions:[PhysicalDimension],_ vDimensions:[PhysicalDimension]) throws(MechanismError) {
            for i in qDimensions.indices { guard constraints.layout.dimensions[position+i] == qDimensions[i] else { throw .unsupportedChart } }
            for i in vDimensions.indices { guard velocityLayout.dimensions[velocity+i] == vDimensions[i] else { throw .unsupportedChart } }
        }
        switch model.tree.rootBase {
        case .fixed: break
        case .planarFloating: try require(0,0,[.length,.length,.angle],[.length,.length,.angle])
        case .spatialFloating: try require(0,0,[.length,.length,.length,.dimensionless,.dimensionless,.dimensionless,.dimensionless],[.length,.length,.length,.angle,.angle,.angle])
        }
        for entry in model.tree.layout.joints {
            guard let source=model.descriptor.joints.first(where:{$0.record.id == entry.joint}) else { throw .staleBinding }
            let manifold=source.record.manifold
            switch manifold.kind {
            case .spherical: try require(entry.positions.start,entry.velocities.start,[.dimensionless,.dimensionless,.dimensionless,.dimensionless],[.angle,.angle,.angle])
            case .sixDOF: try require(entry.positions.start,entry.velocities.start,[.length,.length,.length,.dimensionless,.dimensionless,.dimensionless,.dimensionless],[.length,.length,.length,.angle,.angle,.angle])
            default:
                for i in manifold.orderedAxes.indices {
                    let expected:PhysicalDimension=manifold.orderedAxes[i].kind == .prismatic ? .length : .angle
                    try require(entry.positions.start+i,entry.velocities.start+i,[expected],[expected])
                }
            }
        }
        var blocks:[(position:Int,velocity:Int)]=[]
        if model.tree.rootBase == .spatialFloating { blocks.append((3,3)) }
        for entry in model.tree.layout.joints {
            guard let joint=model.descriptor.joints.first(where:{$0.record.id == entry.joint}) else { throw .staleBinding }
            if joint.record.manifold.kind == .spherical { blocks.append((entry.positions.start,entry.velocities.start)) }
            if joint.record.manifold.kind == .sixDOF { blocks.append((entry.positions.start+3,entry.velocities.start+3)) }
        }
        let square:Int,totalRows:Int
        do { square=try NumericalWork.product(p,p);totalRows=try NumericalWork.sum(constraints.rows.count,blocks.count) } catch { throw .capacityExceeded }
        guard totalRows <= projection.position.evaluation.maximumRows else { throw .capacityExceeded }
        for row in constraints.rows {
            guard row.linear.count == p,row.mixedTime.count == p,row.hessian.count == square else { throw .invalidShape }
        }
        var rows=constraints.rows
        for (index,block) in blocks.enumerated() {
            let id=UInt64.max-UInt64(index)
            guard !rows.contains(where:{$0.id == id}) else { throw .invalidInput }
            var h=[Double](repeating:0,count:square)
            for i in block.position..<(block.position+4) { h[i*p+i]=2*constraints.layout.scales[i]*constraints.layout.scales[i] }
            rows.append(QuadraticConstraint(id:id,constant:-1,linear:[Double](repeating:0,count:p),hessian:h,timeLinear:0,timeQuadratic:0,mixedTime:[Double](repeating:0,count:p)))
        }
        let augmented:QuadraticConstraintSystem
        do throws(ConstraintError) { augmented=try QuadraticConstraintSystem(layout:constraints.layout,rows:rows,minimumPosition:constraints.minimumPosition,
            maximumPosition:constraints.maximumPosition,minimumTime:constraints.minimumTime,maximumTime:constraints.maximumTime) } catch { throw .constraint(error) }
        let bound=try NonlinearPhysicalEngine.bind(model)
        var dimensions=constraints.layout.dimensions
        for d in velocityLayout.dimensions { guard d.time > Int8.min else { throw .invalidInput };dimensions.append(PhysicalDimension(length:d.length,mass:d.mass,time:d.time-1,angle:d.angle,electricCurrent:d.electricCurrent,temperature:d.temperature,amount:d.amount,luminousIntensity:d.luminousIntensity)) }
        let chart=try NonlinearMechanismChart.signature(augmented,velocity:velocityLayout,drive:drive,policy:policy,projection:projection,maximum:maximumIdentityBytes)
        do { descriptor=try ODEDescriptor(identity:identity,chart:chart,model:model.stamp,dimensions:dimensions,maximumIdentityBytes:maximumIdentityBytes,
            maximumCoordinates:try NumericalWork.sum(projection.position.evaluation.maximumCoordinates,policy.maximumCoordinates)) } catch { throw .invalidInput }
        self.model=model;self.constraints=augmented;self.velocityLayout=velocityLayout;self.drive=drive;self.policy=policy;self.projection=projection
        quaternionBlocks=blocks;self.evaluator=evaluator;self.ranker=ranker;self.linear=linear
        let storage:Int
        do { storage=try NumericalWork.sum(try NumericalWork.product(256,try NumericalWork.product(model.tree.bodies.count,max(1,n))),try NumericalWork.sum(try NumericalWork.product(16,try NumericalWork.product(p,n)),try NumericalWork.sum(try NumericalWork.product(16,try NumericalWork.product(totalRows,max(p,totalRows))),try NumericalWork.product(32,try NumericalWork.sum(p,n))))) }
        catch { throw .capacityExceeded }
        physical=NonlinearPhysicalEngine(model:model,velocityLayout:velocityLayout,drive:drive,policy:policy,admission:admission,inertias:bound,kernel:kernel,solver:solver,storage:storage)
    }
    public func validate(model:CompiledMechanicalModel) throws(RuntimeFailure) {
        guard model.stamp == self.model.stamp,model.descriptor == self.model.descriptor,model.tree.layout == self.model.tree.layout else { throw RuntimeFailure(.incompatibleModel,message:"Nonlinear equation model/chart differs.") }
    }
    public func read(_ state:KinematicState,into point:inout [Double]) throws(RuntimeFailure) {
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount
        guard state.revision == model.stamp.revision,state.q.count == p,state.v.count == n,point.count == p+n else { throw RuntimeFailure(.invalidState,message:"Nonlinear state chart differs.") }
        for i in 0..<p { point[i]=state.q[i] };for i in 0..<n { point[p+i]=state.v[i] }
    }
    public func read(_ trial:RuntimeTrial,into point:inout [Double]) throws(RuntimeFailure) {
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount
        guard point.count == p+n else { throw RuntimeFailure(.invalidState,message:"Nonlinear trial chart differs.") }
        for i in 0..<p { point[i]=try trial.position(at:i) };for i in 0..<n { point[p+i]=try trial.velocity(at:i) }
    }
    public func prepare(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try reserve(&work,control:control)
        var point=[Double](repeating:0,count:descriptor.dimensions.count);try read(trial,into:&point)
        try validateInitial(time:trial.timeSeconds,point:point,work:&work,control:control)
    }
    public func validateInitial(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try reserve(&work,control:control)
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount
        guard point.count == p+n,point.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Invalid nonlinear point.") }
        let q=Array(point[..<p]),v=Array(point[p...]),snapshot=try snapshot(q:q,v:v,time:time,work:&work,control:control)
        let e=try evaluate(q:q,rate:snapshot.coordinateRate,time:time,work:&work,control:control)
        _=try original(e,position:true,velocity:true,work:&work)
    }
    public func derivative(time:Double,point:[Double],into output:inout [Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        let result=try consistent(time:time,point:point,work:&work,control:control)
        guard output.count == descriptor.dimensions.count else { throw RuntimeFailure(.invalidState,message:"Nonlinear derivative shape differs.") }
        let p=model.tree.layout.positionCount
        for i in 0..<p { output[i]=result.acceleration.sourceSnapshot.coordinateRate[i] }
        for i in result.acceleration.values.indices { output[p+i]=result.acceleration.values[i] }
    }
    public func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) {
        // The projected evolution owner validates endpoint consistency before calling this exact chart publication.
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount
        guard point.count == p+n,derivative.count == p+n,point.allSatisfy({$0.isFinite}),derivative.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Nonlinear endpoint shape/nonfinite failure.") }
        let tau=time/constraints.layout.timeScale
        guard time >= constraints.minimumTime,time <= constraints.maximumTime else { throw RuntimeFailure(.invalidState,message:"Nonlinear endpoint is outside time domain.") }
        for i in 0..<p { guard point[i] >= constraints.minimumPosition[i],point[i] <= constraints.maximumPosition[i] else { throw RuntimeFailure(.invalidState,message:"Nonlinear endpoint is outside position domain.") } }
        // Original polynomial acceptance prevents the ordinary exact-endpoint integrator from publishing an unprojected loop endpoint.
        for row in constraints.rows {
            var value=row.constant+row.timeLinear*tau+0.5*row.timeQuadratic*tau*tau
            var rate=row.timeLinear+row.timeQuadratic*tau
            for i in 0..<p {
                let x=point[i]/constraints.layout.scales[i]
                value+=row.linear[i]*x+tau*row.mixedTime[i]*x;rate+=row.mixedTime[i]*x
                var gradient=row.linear[i]+tau*row.mixedTime[i]
                for j in 0..<p { let y=point[j]/constraints.layout.scales[j];value+=0.5*x*row.hessian[i*p+j]*y;gradient+=row.hessian[i*p+j]*y }
                rate+=gradient*derivative[i]*constraints.layout.timeScale/constraints.layout.scales[i]
            }
            guard value.isFinite,rate.isFinite,abs(value) <= projection.position.originalResidualTolerance,abs(rate) <= policy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Exact nonlinear endpoint violates original position/velocity rows.") }
        }
        for i in 0..<p { try trial.setPosition(point[i],at:i) }
        for i in 0..<n { try trial.setVelocity(point[p+i],at:i);try trial.setAcceleration(derivative[p+i],at:i) }
        try trial.setTime(time)
    }
    @inline(never)
    public func consistent(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> NonlinearMechanismState {
        try reserve(&work,control:control)
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount
        guard point.count == p+n,point.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Invalid nonlinear point.") }
        let before=Array(point[..<p]);var q=before;let v=Array(point[p...])
        try projectPosition(&q,time:time,work:&work,control:control)
        var correction=0.0
        for i in 0..<p { try charge(4,&work);let d=(q[i]-before[i])/constraints.layout.scales[i];correction+=projection.position.diagonalMetric[i]*d*d }
        correction=correction.squareRoot()
        guard correction.isFinite,correction <= projection.maximumCorrection else { throw RuntimeFailure(.invalidState,message:"Nonlinear position correction exceeds caller limit.") }
        let reconciled=try reconcile(q:q,v:v,time:time,work:&work,control:control)
        return try finishConsistency(q:q,reconciled:reconciled,time:time,correction:correction,work:&work,control:control)
    }
    @inline(never)
    private func reconcile(q:[Double],v:[Double],time:Double,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> ConstrainedMotion {
        let context=try physicalContext(q:q,v:v,time:time,impulse:true,work:&work,control:control)
        return try solve(context,work:&work,control:control)
    }
    @inline(never)
    private func finishConsistency(q:[Double],reconciled:ConstrainedMotion,time:Double,correction:Double,
                                   work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> NonlinearMechanismState {
        let final=try physicalContext(q:q,v:reconciled.values,time:time,impulse:false,work:&work,control:control)
        let acceleration=try solve(final,work:&work,control:control)
        let n=model.tree.layout.velocityCount
        var energy=0.0
        for i in 0..<n { for j in 0..<n { try charge(4,&work);energy+=0.5*reconciled.values[i]*final.system.massMatrix[i*n+j]*reconciled.values[j] } }
        guard energy.isFinite else { throw RuntimeFailure(.invalidState,message:"Kinetic energy overflow.") }
        return NonlinearMechanismState(point:q+reconciled.values,acceleration:acceleration,velocity:reconciled,positionResidual:final.positionResidual,
                                      velocityResidual:final.velocityResidual,correction:correction,kineticEnergy:energy)
    }
    private func projectPosition(_ q:inout [Double],time:Double,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        let p=q.count,zero=[Double](repeating:0,count:p)
        for _ in 0..<projection.maximumIterations {
            try control.beginWorkBlock(units:1);try iteration(&work)
            let e=try evaluate(q:q,rate:zero,time:time,work:&work,control:control)
            if e.values.allSatisfy({abs($0) <= projection.position.originalResidualTolerance}) { return }
            let sample=VelocityConstraintSample(layout:constraints.layout,holonomic:e)
            let rank=try rank(sample,policy:projection.position,work:&work,control:control)
            let r=rank.rank
            guard r > 0 else { throw RuntimeFailure(.invalidState,message:"Original nonlinear rows inconsistent at zero rank.") }
            var gram=[Double](repeating:0,count:r*r),rhs=[Double](repeating:0,count:r)
            for i in 0..<r {
                rhs[i]=e.values[rank.independentRows[i]]
                for j in 0..<r { for k in 0..<p { try charge(4,&work);gram[i*r+j]+=e.jacobian[rank.independentRows[i]*p+k]*e.jacobian[rank.independentRows[j]*p+k]/projection.position.diagonalMetric[k] } }
            }
            let solution=try linearSolve(gram,rhs:rhs,work:&work,control:control)
            for i in 0..<p {
                var delta=0.0
                for j in 0..<r { try charge(3,&work);delta+=e.jacobian[rank.independentRows[j]*p+i]*solution[j]/projection.position.diagonalMetric[i] }
                try charge(2,&work);q[i]-=constraints.layout.scales[i]*delta
                guard q[i].isFinite else { throw RuntimeFailure(.invalidState,message:"Nonlinear projection overflow.") }
            }
        }
        throw RuntimeFailure(.capacityExceeded,message:"Nonlinear position projection iteration limit.")
    }
    private func original(_ e:ConstraintEvaluation,position:Bool,velocity:Bool,work:inout NumericalWork) throws(RuntimeFailure) -> (position:Double,velocity:Double) {
        let p=constraints.layout.scales.count;var rp=0.0,rv=0.0
        for row in e.rowIDs.indices {
            try charge(1,&work);rp=max(rp,abs(e.values[row]));var value=e.timeDerivative[row]
            for i in 0..<p { try charge(2,&work);value+=e.jacobian[row*p+i]*e.normalizedVelocity[i] }
            rv=max(rv,abs(value))
        }
        guard rp.isFinite,rv.isFinite,(!position || rp <= projection.position.originalResidualTolerance),(!velocity || rv <= policy.originalTolerance) else { throw RuntimeFailure(.invalidState,message:"Original nonlinear position/velocity rows are inconsistent.") }
        return (rp,rv)
    }

    private func evaluate(q:[Double],rate:[Double],time:Double,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> ConstraintEvaluation {
        var local=try supplier(&work,control:control);let before=local
        var result:ConstraintEvaluation?,failure:ConstraintError?
        do throws(ConstraintError) { result=try evaluator.evaluate(constraints,position:q,velocity:rate,time:time,policy:projection.position.evaluation,work:&local) } catch { failure=error }
        try finish(local,before:before,into:&work)
        if let failure {
            if case .cancelled=failure { throw RuntimeFailure(.cancelled,message:"Original quadratic supplier cancelled.") }
            throw RuntimeFailure(.invalidState,message:"Original quadratic evaluation failed.",failedSupplierWorkUnavailable:MechanismError.constraint(failure).failedSupplierWorkUnavailable) }
        guard let e=result,e.rowIDs == constraints.rows.map({$0.id}),e.values.count == constraints.rows.count,e.jacobian.count == constraints.rows.count*q.count,
              e.normalizedVelocity.count == q.count,e.normalizedPosition.count == q.count,e.timeDerivative.count == constraints.rows.count,e.accelerationBias.count == constraints.rows.count,e.layoutRevision == model.stamp.revision else { throw RuntimeFailure(.invalidState,message:"Constraint result original shape differs.") }
        for i in q.indices {
            guard e.normalizedPosition[i].isFinite,e.normalizedVelocity[i].isFinite,
                  abs(e.normalizedPosition[i]-q[i]/constraints.layout.scales[i]) <= policy.originalTolerance,
                  abs(e.normalizedVelocity[i]-rate[i]*constraints.layout.timeScale/constraints.layout.scales[i]) <= policy.originalTolerance else {
                throw RuntimeFailure(.invalidState,message:"Constraint supplier changed original scaled coordinates/rates.")
            }
        }
        // Verify each original polynomial independently; supplied diagnostic residuals are not authority.
        let t=constraints.layout.timeScale,tau=time/t
        for row in constraints.rows.indices {
            let source=constraints.rows[row];var value=source.constant+source.timeLinear*tau+0.5*source.timeQuadratic*tau*tau
            var dt=source.timeLinear+source.timeQuadratic*tau,bias=source.timeQuadratic
            for i in q.indices {
                let x=q[i]/constraints.layout.scales[i],u=rate[i]*t/constraints.layout.scales[i]
                try charge(16,&work);value+=source.linear[i]*x+tau*source.mixedTime[i]*x;dt+=source.mixedTime[i]*x;bias+=2*source.mixedTime[i]*u
                var gradient=source.linear[i]+tau*source.mixedTime[i]
                for j in q.indices {
                    try charge(12,&work);let y=q[j]/constraints.layout.scales[j],z=rate[j]*t/constraints.layout.scales[j],h=source.hessian[i*q.count+j]
                    value+=0.5*x*h*y;gradient+=h*y;bias+=u*h*z
                }
                guard abs(gradient-e.jacobian[row*q.count+i]) <= policy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Constraint supplier changed original gradient.") }
            }
            guard value.isFinite,dt.isFinite,bias.isFinite,abs(value-e.values[row]) <= policy.originalTolerance,
                  abs(dt-e.timeDerivative[row]) <= policy.originalTolerance,abs(bias-e.accelerationBias[row]) <= policy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Constraint supplier changed original polynomial/time bias.") }
        }
        return e
    }
    private func tangent(_ e:ConstraintEvaluation,q:[Double],v:[Double],time:Double,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> VelocityConstraintSample {
        let p=q.count,n=v.count,m=constraints.rows.count,t=velocityLayout.timeScale
        var map=[Double](repeating:0,count:p*n),basis=[Double](repeating:0,count:n),ndot=[Double](repeating:0,count:p)
        for j in 0..<n {
            if j > 0 { basis[j-1]=0 };basis[j]=1
            let sample=try snapshot(q:q,v:basis,time:time,work:&work,control:control)
            for i in 0..<p { map[i*n+j]=sample.coordinateRate[i] }
        }
        for block in quaternionBlocks {
            var square=0.0
            for j in block.velocity..<(block.velocity+3) { try charge(2,&work);square+=v[j]*v[j] }
            for i in block.position..<(block.position+4) { try charge(2,&work);ndot[i] = -0.25*square*q[i] }
        }
        // Unit-norm rows carry no mechanical velocity restriction. Original norm consistency is checked separately.
        let physicalRows=m-quaternionBlocks.count
        var rows=[Double](repeating:0,count:physicalRows*n),bias=Array(e.accelerationBias[..<physicalRows])
        for row in 0..<physicalRows {
            for i in 0..<p {
                try charge(4,&work);bias[row]+=t*t*e.jacobian[row*p+i]*ndot[i]/constraints.layout.scales[i]
                for j in 0..<n { try charge(4,&work);rows[row*n+j]+=e.jacobian[row*p+i]*map[i*n+j]*velocityLayout.scales[j]/constraints.layout.scales[i] }
            }
        }
        return VelocityConstraintSample(layout:velocityLayout,rowIDs:Array(e.rowIDs[..<physicalRows]),rows:rows,
            drift:Array(e.timeDerivative[..<physicalRows]),accelerationBias:bias,isIntegrable:true)
    }
    @inline(never)
    private func physicalContext(q:[Double],v:[Double],time:Double,impulse:Bool,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> NonlinearPhysicalSolveContext {
        let assembled=try system(q:q,v:v,time:time,work:&work,control:control)
        let evaluation=try evaluate(q:q,rate:assembled.input.snapshot.coordinateRate,time:time,work:&work,control:control)
        let residual:(position:Double,velocity:Double)
        if impulse { residual=(0,0) }
        else { residual=try original(evaluation,position:true,velocity:true,work:&work) }
        let sample=try tangent(evaluation,q:q,v:v,time:time,work:&work,control:control)
        return NonlinearPhysicalSolveContext(system:assembled,sample:sample,impulse:impulse,positionResidual:residual.position,velocityResidual:residual.velocity)
    }

    private func rank(_ sample:VelocityConstraintSample,policy:ConstraintSolvePolicy,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> ConstraintRankEvidence {
        var local=try supplier(&work,control:control);let before=local;var result:ConstraintRankEvidence?,failure:ConstraintError?
        do throws(ConstraintError) { result=try ranker.rank(sample,policy:policy,work:&local) } catch { failure=error }
        try finish(local,before:before,into:&work)
        if let failure { throw RuntimeFailure(.invalidState,message:"Projection rank supplier failed.",failedSupplierWorkUnavailable:MechanismError.constraint(failure).failedSupplierWorkUnavailable) }
        guard let rank=result,rank.rank >= 0,rank.rank <= min(sample.layout.scales.count,sample.rowIDs.count),rank.independentRows.count == rank.rank,
              rank.independentRows.allSatisfy({sample.rowIDs.indices.contains($0)}),Set(rank.independentRows).count == rank.rank else { throw RuntimeFailure(.invalidState,message:"Invalid rank evidence.") }
        return rank
    }
    private func linearSolve(_ matrix:[Double],rhs:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> [Double] {
        try control.beginWorkBlock(units:1);try charge(1,&work)
        let budget:NumericalBudget,dense:DenseMatrix<Double>
        do { budget=try work.remainingBudget(reservedStorage:reservedSlots());dense=try DenseMatrix(rows:rhs.count,columns:rhs.count,values:matrix) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Projection linear admission budget exhausted.") }
        let solution:LinearSolution<Double>
        do throws(NumericalError) { solution=try linear.solve(dense,rightHandSide:rhs,capability:projection.position.linearCapability,tolerance:projection.position.linearTolerance,budget:budget) }
        catch { throw RuntimeFailure(.invalidState,message:"Projection linear supplier failed; partial work unavailable.",failedSupplierWorkUnavailable:true) }
        guard solution.diagnostics.work.budget == budget,solution.diagnostics.work.operations > 0 else { throw RuntimeFailure(.invalidOwnerAccess,message:"Linear supplier changed admitted budget.",failedSupplierWorkUnavailable:true) }
        do { try work.absorb(solution.diagnostics.work,reservedStorage:reservedSlots()) } catch { throw RuntimeFailure(.capacityExceeded,message:"Projection aggregate work exhausted.") }
        guard solution.values.count == rhs.count,solution.values.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Projection linear result invalid.") }
        for i in rhs.indices {
            var residual = -rhs[i],scale=abs(rhs[i])
            for j in rhs.indices { try charge(4,&work);let term=matrix[i*rhs.count+j]*solution.values[j];residual+=term;scale+=abs(term) }
            let tolerance=projection.position.linearTolerance
            guard residual.isFinite,scale.isFinite,abs(residual) <= tolerance.absoluteResidual+tolerance.relativeResidual*scale else { throw RuntimeFailure(.invalidState,message:"Original position Gram equation rejects supplier solution.") }
        }
        return solution.values
    }

    private func reservedSlots() throws(NumericalError) -> Int {
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount,m=constraints.rows.count,b=model.tree.bodies.count
        return try NumericalWork.sum(try NumericalWork.product(256,try NumericalWork.product(b,max(1,n))),try NumericalWork.sum(try NumericalWork.product(16,try NumericalWork.product(p,n)),try NumericalWork.sum(try NumericalWork.product(16,try NumericalWork.product(m,max(p,m))),try NumericalWork.product(32,try NumericalWork.sum(p,n)))))
    }
    private func reserve(_ work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1)
        guard !policy.isCancelled(),!projection.position.evaluation.isCancelled() else { throw RuntimeFailure(.cancelled,message:"Nonlinear equation cancelled.") }
        do { try work.requireStorage(reservedSlots()) } catch { throw RuntimeFailure(.capacityExceeded,message:"Nonlinear orchestration scalar envelope exhausted.") }
    }

    private func iteration(_ work:inout NumericalWork) throws(RuntimeFailure) {
        do { try work.advanceIteration() } catch { throw RuntimeFailure(.capacityExceeded,message:"Nonlinear projection iteration budget exhausted.") }
    }
    private func snapshot(q:[Double],v:[Double],time:Double,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> KinematicSnapshot {
        try physical.snapshot(q:q,v:v,time:time,work:&work,control:control)
    }
    private func system(q:[Double],v:[Double],time:Double,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> PhysicalRigidDynamicsSystem {
        try physical.system(q:q,v:v,time:time,work:&work,control:control)
    }
    @inline(never)
    private func solve(_ context:NonlinearPhysicalSolveContext,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> ConstrainedMotion {
        try physical.solve(context,work:&work,control:control)
    }
    private func supplier(_ work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> NumericalWork { try physical.supplier(&work,control:control) }
    private func finish(_ local:NumericalWork,before:NumericalWork,into work:inout NumericalWork) throws(RuntimeFailure) { try physical.finish(local,before:before,into:&work) }
    private func charge(_ count:Int,_ work:inout NumericalWork) throws(RuntimeFailure) { try physical.charge(count,&work) }
    public func writeAccepted(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1)
        try write(point:point,derivative:derivative,time:time,trial:&trial)
    }

}
