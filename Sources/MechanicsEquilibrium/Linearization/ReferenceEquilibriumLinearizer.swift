import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsNonlinear
import MechanicsConstraints
import MechanicsJoints
import MechanicsCompiler
import MechanicsLoads
import MechanicsDynamics

public struct ReferenceEquilibriumLinearizer: EquilibriumLinearizing, Sendable {
    public let forces: any StaticForceEvaluating<Double>
    public let inertia: any RigidEquationComputing
    public let linear: any LinearSolving<Double>
    public init(forces: any StaticForceEvaluating<Double> = ReferenceStaticForceEvaluator<Double>(), inertia: any RigidEquationComputing = RigidEquationKernel(), linear: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) {
        self.forces=forces;self.inertia=inertia;self.linear=linear
    }
    @inline(never)
    public func linearize(_ point:EquilibriumSolution,compiled:CompiledMechanicalModel,dynamics:RigidDynamicsSystem,reduction:EquilibriumReduction,
                          policy:EquilibriumLinearizationPolicy,work:inout NumericalWork)throws(EquilibriumError)->EquilibriumLinearization {
        let n=point.model.chart.count;let k=reduction.freeCoordinates;let o=reduction.outputRows
        guard !policy.isCancelled() else { throw .cancelled }
        guard n<=policy.limits.coordinates,compiled.tree.bodies.count<=policy.limits.bodies,(point.constraints?.system.rows.count ?? 0)<=policy.limits.rows,o>0,o<=policy.limits.coordinates,
            policy.derivativeAbsoluteTolerances.count==n,policy.inertialAbsoluteTolerances.count==n else { throw .capacityExceeded }
        // FIXME(INCOMPLETE_IMPLEMENTATION): The first realization has positive free dimension. Fully constrained zero-state realizations need explicit output/reaction parameter sensitivity before admission.
        guard k>0 else { throw .unsupportedDomain }
        guard k==n-point.rank.rank else { throw .invalidReduction }
        let nn=try size(n,n);let nk=try size(n,k);let kk=try size(k,k)
        guard reduction.basis.count==nk,reduction.damping.count==nn,reduction.outputMap.count == (try size(o,n)),reduction.outputDimensions.count==o else { throw .invalidInput }
        try equilibriumNumerics { () throws(NumericalError) in try policy.capability.validate(for:Double.self,algorithms:[.cholesky]) }
        let reserve=try equilibriumNumerics { () throws(NumericalError) in
            let dense=try NumericalWork.sum(try NumericalWork.product(32,nn),try NumericalWork.product(2,try NumericalWork.product(o,k)))
            let binding=try NumericalWork.sum(try NumericalWork.product(6,try NumericalWork.product(n,compiled.tree.bodies.count)),try NumericalWork.product(32,compiled.tree.frameCount))
            return try NumericalWork.sum(dynamics.scalarStorage,try NumericalWork.sum(dense,binding))
        }
        try equilibriumNumerics { () throws(NumericalError) in
            try work.requireStorage(reserve)
            // Bounded own bilinear products, directional comparisons, row checks and metadata association. Suppliers charge their own arithmetic separately.
            let rows=point.constraints?.system.rows.count ?? 0
            var count=try NumericalWork.product(8,try NumericalWork.product(nn,kk))
            for term in [try NumericalWork.product(2,try NumericalWork.product(n,kk)),try NumericalWork.product(2,try NumericalWork.product(o,nk)),
                try NumericalWork.product(4,try NumericalWork.product(nn,k)),try NumericalWork.product(6,try NumericalWork.product(rows,nk)),
                try NumericalWork.product(20,nk),try NumericalWork.product(6,try NumericalWork.product(rows,k)),try NumericalWork.product(10,n),try NumericalWork.product(3,kk),nn,
                try NumericalWork.product(compiled.tree.bodies.count,compiled.tree.bodies.count)] { count=try NumericalWork.sum(count,term) }
            try work.chargeOperations(count)
        }
        guard reduction.basis.allSatisfy({$0.isFinite}),reduction.damping.allSatisfy({$0.isFinite}),reduction.outputMap.allSatisfy({$0.isFinite}) else { throw .invalidInput }
        try binding(point,compiled:compiled,dynamics:dynamics,policy:policy,work:&work)
        try validateBasis(point,reduction:reduction,policy:policy,reserve:reserve,work:&work)
        let derivatives=try derivatives(point,reduction:reduction,policy:policy,work:&work)
        let error=try inertialChecks(dynamics,reduction:reduction,policy:policy,work:&work)
        var mass=[Double](repeating:0,count:kk);var stiffness=mass;var damping=mass;var input=[Double](repeating:0,count:k)
        for a in 0..<k { for b in 0..<k { var m=0.0;var h=0.0;var d=0.0
            for i in 0..<n { for j in 0..<n {
                let factor=reduction.basis[i*k+a]*reduction.basis[j*k+b]
                m += factor*dynamics.massMatrix[i*n+j];h += factor*derivatives.hessian[i*n+j];d += factor*reduction.damping[i*n+j]
            } }
            mass[a*k+b]=m;stiffness[a*k+b]=h;damping[a*k+b]=d
        } }
        for a in 0..<k { for i in 0..<n { input[a] -= reduction.basis[i*k+a]*derivatives.parameter[i] } }
        // Roundoff symmetry is explicitly constructed from the same bilinear operator, without altering diagonal or eigenvalues.
        for i in 0..<k { for j in 0..<i { mass[j*k+i]=mass[i*k+j] } }
        let states=try size(2,k);var A=[Double](repeating:0,count:try size(states,states));var B=[Double](repeating:0,count:states);var C=[Double](repeating:0,count:try size(o,states))
        var rhs=[Double](repeating:0,count:k)
        for i in 0..<k { A[i*states+k+i]=1 }
        for j in 0..<k {
            guard !policy.isCancelled() else { throw .cancelled }
            for i in 0..<k { rhs[i] = -stiffness[i*k+j] }
            let x=try solve(mass,dimension:k,rhs:rhs,policy:policy,reserve:reserve,work:&work)
            for i in 0..<k { A[(k+i)*states+j]=x[i] }
            for i in 0..<k { rhs[i] = -damping[i*k+j] }
            let y=try solve(mass,dimension:k,rhs:rhs,policy:policy,reserve:reserve,work:&work)
            for i in 0..<k { A[(k+i)*states+k+j]=y[i] }
        }
        let drive=try solve(mass,dimension:k,rhs:input,policy:policy,reserve:reserve,work:&work)
        for i in 0..<k { B[k+i]=drive[i] }
        for a in 0..<o { for b in 0..<k { for i in 0..<n { C[a*states+b] += reduction.outputMap[a*n+i]*reduction.basis[i*k+b] } } }
        guard mass.allSatisfy({$0.isFinite}),stiffness.allSatisfy({$0.isFinite}),damping.allSatisfy({$0.isFinite}),A.allSatisfy({$0.isFinite}),B.allSatisfy({$0.isFinite}),C.allSatisfy({$0.isFinite}) else { throw .nonFiniteResult }
        guard !policy.isCancelled() else { throw .cancelled }
        return EquilibriumLinearization(operatingPoint:point,reduction:reduction,reducedMass:mass,reducedStiffness:stiffness,reducedDamping:damping,stateMatrix:A,inputMatrix:B,outputMatrix:C,
            maximumDirectionalError:derivatives.error,maximumInertialError:error,work:work)
    }
    @inline(never)
    private func binding(_ point:EquilibriumSolution,compiled:CompiledMechanicalModel,dynamics:RigidDynamicsSystem,policy:EquilibriumLinearizationPolicy,work:inout NumericalWork)throws(EquilibriumError) {
        let chart=point.model.chart;let n=chart.count;let tree=compiled.tree;let old=dynamics.input.snapshot
        guard chart.stamp==compiled.stamp,chart.frame==tree.worldFrame,tree.revision==chart.stamp.revision else { throw .staleBinding }
        guard tree.layout.positionCount==n,tree.layout.velocityCount==n,dynamics.velocityCount==n,old.time==point.time else { throw .operatingPointMismatch }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Only fixed-base, spatial scalar dynamic charts with fixed anchors are bound here. Free, prescribed, planar, coupled and custom charts need actual q-v derivative and inertia association evidence before admission.
        guard tree.rootBase == .fixed else { throw .unsupportedDomain }
        var offset=0
        for joint in tree.joints {
            if joint.manifold.kind == .fixed { continue }
            guard joint.manifold.kind == .revolute || joint.manifold.kind == .prismatic || joint.manifold.kind == .screw,
                joint.manifold.positionCount==1,joint.manifold.velocityCount==1 else { throw .unsupportedDomain }
            guard offset<n,chart.joints[offset]==joint.id else { throw .staleBinding }
            let dimension:PhysicalDimension=joint.manifold.kind == .prismatic ? .length : .angle
            guard chart.dimensions[offset]==dimension else { throw .staleBinding }
            guard case .fixed=joint.parentAnchor.placement,case .fixed=joint.childAnchor.placement else { throw .unsupportedDomain }
            offset += 1
        }
        guard offset==n,compiled.descriptor.rootAuthority == .fixed else { throw .unsupportedDomain }
        for joint in compiled.descriptor.joints { if joint.record.manifold.velocityCount>0 { guard joint.authority == .dynamicState else { throw .unsupportedDomain } } }
        guard old.tree.layout==tree.layout,old.tree.bodies==tree.bodies,old.tree.joints==tree.joints,old.tree.rootBase==tree.rootBase,old.tree.worldFrame==tree.worldFrame,
            old.tree.revision==tree.revision,dynamics.input.inertias.count==compiled.descriptor.bodies.count else { throw .operatingPointMismatch }
        for body in compiled.descriptor.bodies {
            guard case .spatial(let record)=body else { throw .unsupportedDomain }
            guard let original=record.inertia else { throw .invalidInput }
            var matched=false
            for supplied in dynamics.input.inertias { if supplied.body==record.id {
                guard supplied.frame==record.frame,supplied.properties==original.properties else { throw .operatingPointMismatch };matched=true
            } }
            guard matched else { throw .operatingPointMismatch }
        }
        let zero=[Double](repeating:0,count:n);let fresh:KinematicSnapshot
        do { let state=try KinematicState(revision:chart.stamp.revision,time:point.time,q:point.position,v:zero,acceleration:zero)
            fresh=try compiled.evaluate(compiled.makeState(state))
        } catch { throw .compilation }
        guard fresh.bodies==old.bodies,fresh.frames==old.frames,fresh.joints==old.joints,fresh.coordinateRate==old.coordinateRate,dynamics.input.velocity==zero else { throw .operatingPointMismatch }
        var original=zero
        do { try inertia.originalInertialForce(dynamics,acceleration:zero,includeBias:true,into:&original,work:&work) } catch { throw .dynamics(error) }
        guard original.count==n else { throw .invalidInput }
        for i in 0..<n { guard original[i].isFinite,abs(original[i])<=policy.inertialAbsoluteTolerances[i] else { throw .operatingPointMismatch } }
    }
    @inline(never)
    private func validateBasis(_ point:EquilibriumSolution,reduction:EquilibriumReduction,policy:EquilibriumLinearizationPolicy,reserve:Int,work:inout NumericalWork)throws(EquilibriumError) {
        let n=point.model.chart.count;let k=reduction.freeCoordinates
        if let c=point.constraints { for row in c.system.rows { for j in 0..<k { var value=0.0
            for i in 0..<n { value += row.linear[i]*reduction.basis[i*k+j]/point.model.chart.scales[i] }
            guard value.isFinite,abs(value)<=policy.constraintTolerance else { throw .invalidReduction }
        } } }
        var gram=[Double](repeating:0,count:try size(k,k))
        for a in 0..<k { for b in 0...a { var value=0.0
            for i in 0..<n { value += reduction.basis[i*k+a]*reduction.basis[i*k+b] }
            gram[a*k+b]=value;gram[b*k+a]=value
        } }
        _ = try solve(gram,dimension:k,rhs:[Double](repeating:0,count:k),policy:policy,reserve:reserve,work:&work)
        for i in 0..<n { for j in 0..<n { guard reduction.damping[i*n+j]==reduction.damping[j*n+i] else { throw .invalidInput } } }
        // D is a published linear law and may include active negative damping; no passive or stability classification is inferred.
    }
    @inline(never)
    private func derivatives(_ point:EquilibriumSolution,reduction:EquilibriumReduction,policy:EquilibriumLinearizationPolicy,work:inout NumericalWork)throws(EquilibriumError)->(hessian:[Double],parameter:[Double],error:Double) {
        let model=point.model;let n=model.chart.count;let k=reduction.freeCoordinates
        var x=[Double](repeating:0,count:n);var plus=x;var minus=x
        for i in 0..<n { x[i]=point.position[i]/model.chart.scales[i] }
        var H=[Double](repeating:0,count:try size(n,n));var P=[Double](repeating:0,count:n);var maxError=0.0
        for i in 0..<n {
            let actual=try equilibriumForce { () throws(StaticForceError) in try forces.gradient(model,point:x,parameter:point.parameter,coordinate:i,work:&work) }
            try checkDerivative(abs(actual-point.physicalGradient[i]),scale:max(abs(actual),abs(point.physicalGradient[i])),coordinate:i,policy:policy)
        }
            for i in 0..<n { P[i]=try equilibriumForce { () throws(StaticForceError) in try forces.parameterDerivative(model,point:x,parameter:point.parameter,coordinate:i,work:&work) }
                for j in 0..<n { H[i*n+j]=try equilibriumForce { () throws(StaticForceError) in try forces.tangent(model,point:x,parameter:point.parameter,row:i,column:j,work:&work) } }
            }
            for col in 0..<k {
                guard !policy.isCancelled() else { throw .cancelled }
                for i in 0..<n { let delta=policy.displacementProbe*reduction.basis[i*k+col]/model.chart.scales[i];plus[i]=x[i]+delta;minus[i]=x[i]-delta }
                try constraintDirections(point,plus:plus,minus:minus,reduction:reduction,column:col,policy:policy,work:&work)
                for i in 0..<n {
                    let gp=try equilibriumForce { () throws(StaticForceError) in try forces.gradient(model,point:plus,parameter:point.parameter,coordinate:i,work:&work) }
                    let gm=try equilibriumForce { () throws(StaticForceError) in try forces.gradient(model,point:minus,parameter:point.parameter,coordinate:i,work:&work) }
                    let original=(gp-gm)/(2*policy.displacementProbe);var analytic=0.0
                    for j in 0..<n { analytic += H[i*n+j]*reduction.basis[j*k+col] }
                    let e=abs(original-analytic);maxError=max(maxError,e)
                    try checkDerivative(e,scale:max(abs(original),abs(analytic)),coordinate:i,policy:policy)
                }
            }
            for i in 0..<n {
                let gp=try equilibriumForce { () throws(StaticForceError) in try forces.gradient(model,point:x,parameter:point.parameter+policy.parameterProbe,coordinate:i,work:&work) }
                let gm=try equilibriumForce { () throws(StaticForceError) in try forces.gradient(model,point:x,parameter:point.parameter-policy.parameterProbe,coordinate:i,work:&work) }
                let original=(gp-gm)/(2*policy.parameterProbe);let e=abs(original-P[i]);maxError=max(maxError,e)
                try checkDerivative(e,scale:max(abs(original),abs(P[i])),coordinate:i,policy:policy)
            }
        guard H.allSatisfy({$0.isFinite}),P.allSatisfy({$0.isFinite}) else { throw .nonFiniteResult }
        for i in 0..<n { for j in 0..<n { guard H[i*n+j]==H[j*n+i] else { throw .invalidInput } } }
        return (H,P,maxError)
    }
    @inline(never)
    private func constraintDirections(_ point:EquilibriumSolution,plus:[Double],minus:[Double],reduction:EquilibriumReduction,column:Int,policy:EquilibriumLinearizationPolicy,work:inout NumericalWork)throws(EquilibriumError) {
        guard let c=point.constraints else { return }
        let n=point.model.chart.count;let k=reduction.freeCoordinates
        var qp=[Double](repeating:0,count:n);var qm=qp;let zero=qp
        for i in 0..<n { qp[i]=plus[i]*point.model.chart.scales[i];qm[i]=minus[i]*point.model.chart.scales[i] }
        let ep:ConstraintEvaluation;let em:ConstraintEvaluation
        do { ep=try QuadraticConstraintEvaluator().evaluate(c.system,position:qp,velocity:zero,time:point.time,policy:c.policy.evaluation,work:&work)
            em=try QuadraticConstraintEvaluator().evaluate(c.system,position:qm,velocity:zero,time:point.time,policy:c.policy.evaluation,work:&work)
        } catch { throw .constraint(error) }
        guard ep.values.count==c.system.rows.count,em.values.count==c.system.rows.count else { throw .invalidInput }
        for r in c.system.rows.indices {
            let original=(ep.values[r]-em.values[r])/(2*policy.displacementProbe);var analytic=0.0
            for i in 0..<n { analytic += c.system.rows[r].linear[i]*reduction.basis[i*k+column]/point.model.chart.scales[i] }
            guard original.isFinite,abs(original-analytic)<=policy.constraintTolerance else { throw .invalidReduction }
        }
    }
    private func checkDerivative(_ error:Double,scale:Double,coordinate:Int,policy:EquilibriumLinearizationPolicy)throws(EquilibriumError) {
        let threshold=policy.derivativeAbsoluteTolerances[coordinate]+policy.derivativeRelativeTolerance*scale
        guard error.isFinite,threshold.isFinite,error<=threshold else { throw .derivativeMismatch(coordinate:coordinate,error:error) }
    }
    @inline(never)
    private func inertialChecks(_ system:RigidDynamicsSystem,reduction:EquilibriumReduction,policy:EquilibriumLinearizationPolicy,work:inout NumericalWork)throws(EquilibriumError)->Double {
        let n=system.velocityCount;let k=reduction.freeCoordinates;var acceleration=[Double](repeating:0,count:n);var force=acceleration;var maximum=0.0
        for j in 0..<k {
            for i in 0..<n { acceleration[i]=reduction.basis[i*k+j] }
            do { try inertia.originalInertialForce(system,acceleration:acceleration,includeBias:false,into:&force,work:&work) } catch { throw .dynamics(error) }
            guard force.count==n else { throw .invalidInput }
            for i in 0..<n { var matrixAction=0.0;for a in 0..<n { matrixAction += system.massMatrix[i*n+a]*acceleration[a] }
                let e=abs(force[i]-matrixAction);maximum=max(maximum,e)
                guard e.isFinite,e<=policy.inertialAbsoluteTolerances[i] else { throw .operatingPointMismatch }
            }
        }
        return maximum
    }
    @inline(never)
    private func solve(_ values:[Double],dimension:Int,rhs:[Double],policy:EquilibriumLinearizationPolicy,reserve:Int,work:inout NumericalWork)throws(EquilibriumError)->[Double] {
        let matrix=try equilibriumNumerics { () throws(NumericalError) in try DenseMatrix(rows:dimension,columns:dimension,values:values) }
        let budget=try equilibriumNumerics { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserve) }
        let result:LinearSolution<Double>
        do { result=try linear.solve(matrix,rightHandSide:rhs,capability:policy.capability,tolerance:policy.tolerance,budget:budget) }
        catch { throw .linear(error,failedSupplierWorkUnavailable:true) }
        try equilibriumNumerics { () throws(NumericalError) in try work.absorb(result.diagnostics.work,reservedStorage:reserve) }
        guard result.values.count==dimension,result.values.allSatisfy({$0.isFinite}) else { throw .invalidInput }
        return result.values
    }
    private func size(_ a:Int,_ b:Int)throws(EquilibriumError)->Int { try equilibriumNumerics { () throws(NumericalError) in try NumericalWork.product(a,b) } }
}
