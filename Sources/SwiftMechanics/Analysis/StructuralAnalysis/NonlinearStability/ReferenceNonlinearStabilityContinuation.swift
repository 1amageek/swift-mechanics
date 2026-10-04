public struct ReferenceNonlinearStabilityContinuation: NonlinearStabilityContinuing, Sendable {
    public let forces: any StaticForceEvaluating<Double>
    public let equilibrium: any EquilibriumSolving
    public let nonlinear: any NonlinearSolving<Double>
    public let linear: any LinearSolving<Double>
    public let inertia: any RigidEquationComputing
    public let evaluator: any ConstraintEvaluating
    public let spectrum: any ComplexSpectralSolving
    public init(forces: any StaticForceEvaluating<Double> = ReferenceStaticForceEvaluator<Double>(),
                equilibrium: any EquilibriumSolving = ReferenceEquilibriumSolver(),
                nonlinear: any NonlinearSolving<Double> = ReferenceNonlinearSolver<Double>(),
                linear: any LinearSolving<Double> = ReferenceLinearSolver<Double>(),
                inertia: any RigidEquationComputing = RigidEquationKernel(),
                evaluator: any ConstraintEvaluating = QuadraticConstraintEvaluator(),
                spectrum: any ComplexSpectralSolving = ReferenceComplexSpectralSolver()) {
        self.forces=forces;self.equilibrium=equilibrium;self.nonlinear=nonlinear;self.linear=linear
        self.inertia=inertia;self.evaluator=evaluator;self.spectrum=spectrum
    }
    @inline(never)
    public func start(_ source: NonlinearStabilitySource, position: [Double], parameter: Double,
                      initialDirection: [Double], policy: NonlinearStabilityPolicy, work: inout NumericalWork)
        throws(NonlinearStabilityFailure) -> NonlinearStabilityState {
        do { return try initial(source,position:position,parameter:parameter,direction:initialDirection,policy:policy,work:&work) }
        catch { throw NonlinearStabilityFailure(error,work:work) }
    }
    @inline(never)
    public func advance(_ source: NonlinearStabilitySource, state: NonlinearStabilityState, arcStep: Double,
                        policy: NonlinearStabilityPolicy, work: inout NumericalWork)
        throws(NonlinearStabilityFailure) -> NonlinearStabilityState {
        do { return try next(source,state:state,step:arcStep,policy:policy,work:&work) }
        catch { throw NonlinearStabilityFailure(error,work:work,prior:state) }
    }
    @inline(never)
    public func critical(_ source: NonlinearStabilitySource, left: NonlinearStabilityState, right: NonlinearStabilityState,
                         policy: NonlinearStabilityPolicy, work: inout NumericalWork)
        throws(NonlinearStabilityFailure) -> NonlinearStabilityCriticalPoint {
        do { return try refine(source,left:left,right:right,policy:policy,work:&work) }
        catch { throw NonlinearStabilityFailure(error,work:work,prior:right) }
    }
    private typealias Cause = NonlinearStabilityFailure.Cause
    @inline(never)
    private func admit(_ s: NonlinearStabilitySource, policy p: NonlinearStabilityPolicy, work: inout NumericalWork) throws(Cause) {
        try StabilityArithmetic.check(p)
        guard p.equilibrium.physicalForceTolerances.count==s.count,p.evidence.derivativeAbsoluteTolerances.count==s.count,
            p.evidence.inertialAbsoluteTolerances.count==s.count,s.count<=p.equilibrium.limits.coordinates,
            s.count<=p.evidence.limits.coordinates,s.rowCount<=p.equilibrium.limits.rows,
            s.compiled.tree.bodies.count<=p.evidence.limits.bodies else { throw .capacityExceeded }
        try StabilityArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(s.reserve) }
    }
    @inline(never)
    private func initial(_ s: NonlinearStabilitySource, position: [Double], parameter: Double, direction: [Double],
                         policy p: NonlinearStabilityPolicy, work: inout NumericalWork) throws(Cause) -> NonlinearStabilityState {
        try admit(s,policy:p,work:&work)
        guard position.count==s.count,direction.count==s.count+1,parameter.isFinite else { throw .invalidInput }
        try StabilityArithmetic.finite(position);try StabilityArithmetic.finite(direction)
        var oriented=[Double](repeating:0,count:s.dimension)
        for i in 0..<s.count { oriented[i]=direction[i] };oriented[s.dimension-1]=direction[s.count]
        let norm=StabilityArithmetic.norm(oriented,source:s)
        guard norm.isFinite,norm>0 else { throw .invalidInput }
        for i in oriented.indices { oriented[i]/=norm }
        let cap=try StabilityArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:s.reserve) }
        var nested=NumericalWork(budget:cap)
        try StabilityArithmetic.numerical { () throws(NumericalError) in try nested.chargeOperations(1) }
        let seed=nested,initial:EquilibriumSolution
        do { initial=try equilibrium.solve(s.model,constraints:s.constraints,initialPosition:position,parameter:parameter,time:s.time,branch:s.branch,policy:p.equilibrium,work:&nested) }
        catch {
            do { try StabilityArithmetic.prefix(seed,&nested) } catch { try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(seed,reservedStorage:s.reserve) };throw error }
            try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:s.reserve) };throw .equilibrium(error)
        }
        do { try StabilityArithmetic.prefix(seed,&nested) } catch { try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(seed,reservedStorage:s.reserve) };throw error }
        guard initial.work==nested else { try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(seed,reservedStorage:s.reserve) };throw .invalidSupplierWork }
        try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:s.reserve) }
        try StabilityArithmetic.check(p)
        guard initial.model==s.model,initial.branch==s.branch,initial.time==s.time,initial.parameter==parameter,initial.position.count==s.count,
            initial.rowMultipliers.count==s.rowCount,initial.rank.rank==s.rowCount else { throw .invalidSupplierOutput }
        var z=[Double](repeating:0,count:s.dimension)
        for i in 0..<s.count { z[i]=initial.position[i]/s.model.chart.scales[i] }
        for r in 0..<s.rowCount { z[s.count+r]=initial.rowMultipliers[r] };z[s.dimension-1]=parameter/p.parameterScale
        let data=try evidence(s,z:z,predictor:z,direction:oriented,policy:p,work:&work)
        let t=try tangent(s,z:z,direction:oriented,policy:p,work:&work)
        try StabilityArithmetic.check(p)
        return NonlinearStabilityState(source:s,policy:p,point:publish(s,z:z,data:data,work:work,policy:p),tangent:t,
            arcDistance:0,acceptedPoints:1,lineage:NonlinearStabilityState.Lineage())
    }
    @inline(never)
    private func next(_ s: NonlinearStabilitySource, state: NonlinearStabilityState, step: Double,
                      policy p: NonlinearStabilityPolicy, work: inout NumericalWork) throws(Cause) -> NonlinearStabilityState {
        try admit(s,policy:p,work:&work)
        guard state.source===s,state.policy===p else { throw .staleSource }
        guard step.isFinite,step>0,step<=p.maximumArcStep else { throw .invalidInput }
        guard state.acceptedPoints<p.maximumAcceptedPoints else { throw .capacityExceeded }
        try StabilityArithmetic.numerical { () throws(NumericalError) in try work.advanceIteration() }
        let old=coordinates(s,point:state.point,policy:p);var predictor=old
        try StabilityArithmetic.charge(try StabilityArithmetic.product(4,s.dimension),&work)
        for i in predictor.indices { predictor[i]+=step*state.tangent[i] }
        let z=try correct(s,predictor:predictor,direction:state.tangent,initial:predictor,policy:p,work:&work)
        var difference=z;for i in z.indices { difference[i]-=old[i] }
        let traveled=StabilityArithmetic.norm(difference,source:s)
        guard traveled.isFinite,traveled<=s.branch.maximumNormalizedStep else { throw .branchExceeded }
        let data=try evidence(s,z:z,predictor:predictor,direction:state.tangent,policy:p,work:&work)
        let t=try tangent(s,z:z,direction:state.tangent,policy:p,work:&work)
        let distance=state.arcDistance+traveled
        guard distance.isFinite else { throw .nonFiniteResult }
        try StabilityArithmetic.check(p)
        return NonlinearStabilityState(source:s,policy:p,point:publish(s,z:z,data:data,work:work,policy:p),tangent:t,
            arcDistance:distance,acceptedPoints:state.acceptedPoints+1,lineage:state.lineage,precedingStepIdentity:state.stepIdentity)
    }
    @inline(never)
    private func correct(_ s: NonlinearStabilitySource,predictor: [Double],direction: [Double],initial: [Double],
                         policy p: NonlinearStabilityPolicy,work: inout NumericalWork) throws(Cause) -> [Double] {
        try StabilityArithmetic.check(p)
        let eq=StabilityArcEquations(source:s,policy:p,forces:forces,predictor:predictor,direction:direction)
        let np=try StabilityArithmetic.limited(p.equilibrium.nonlinear,work:work,reserve:s.reserve)
        let result:NonlinearSolution<Double>
        do { result=try nonlinear.solve(StabilitySolverEquations(original:eq),initialPoint:initial,policy:np) }
        catch {
            guard error.work.budget==np.budget else { throw .invalidSupplierWork }
            try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(error.work,reservedStorage:s.reserve) };throw .nonlinear(error)
        }
        guard result.diagnostics.work.budget==np.budget else { throw .invalidSupplierWork }
        try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(result.diagnostics.work,reservedStorage:s.reserve) }
        try StabilityArithmetic.check(p)
        guard result.values.count==s.dimension else { throw .invalidSupplierOutput }
        try StabilityArithmetic.finite(result.values)
        var change=result.values
        for i in change.indices { change[i]-=predictor[i] }
        guard StabilityArithmetic.norm(change,source:s)<=p.maximumCorrection else { throw .branchExceeded }
        return result.values
    }
    @inline(never)
    private func tangent(_ s: NonlinearStabilitySource,z: [Double],direction: [Double],policy p: NonlinearStabilityPolicy,
                         work: inout NumericalWork) throws(Cause) -> [Double] {
        let cap=try StabilityArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:s.reserve) }
        var nested=NumericalWork(budget:cap),J=[Double](repeating:0,count:s.dimension*s.dimension)
        let eq=StabilityArcEquations(source:s,policy:p,forces:forces,predictor:z,direction:direction)
        do { try eq.jacobian(at:z,into:&J,work:&nested) }
        catch { try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:s.reserve) };throw .equations(error) }
        try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:s.reserve) }
        var rhs=[Double](repeating:0,count:s.dimension);rhs[s.dimension-1]=1
        var result=try StabilityArithmetic.solve(J,rhs:rhs,supplier:linear,policy:p,reserve:s.reserve,work:&work)
        let norm=StabilityArithmetic.norm(result,source:s)
        guard norm.isFinite,norm>0 else { throw .ambiguousTangent }
        for i in result.indices { result[i]/=norm }
        var dot=result[s.dimension-1]*direction[s.dimension-1]
        for i in 0..<s.count { dot+=result[i]*direction[i] }
        guard dot.isFinite,dot>p.arcTolerance else { throw .ambiguousTangent }
        return result
    }
    internal struct Evidence {
        let original: StabilityOriginalEvidence.Data
        let spectral: StabilitySpectralEvidence.Data
        let inertialError: Double
    }
    @inline(never)
    private func evidence(_ s: NonlinearStabilitySource,z: [Double],predictor: [Double],direction: [Double],
                          policy p: NonlinearStabilityPolicy,work: inout NumericalWork) throws(Cause) -> Evidence {
        let cap=try StabilityArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:s.reserve) }
        var nested=NumericalWork(budget:cap)
        let original:StabilityOriginalEvidence.Data
        do { original=try StabilityOriginalEvidence.evaluate(s,z:z,predictor:predictor,direction:direction,forces:forces,evaluator:evaluator,policy:p,work:&nested) }
        catch { try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:s.reserve) };throw error }
        try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:s.reserve) }
        var q=[Double](repeating:0,count:s.count)
        for i in 0..<s.count { q[i]=z[i]*s.model.chart.scales[i] }
        let massCap=try StabilityArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:s.reserve) }
        var massWork=NumericalWork(budget:massCap)
        let mass:(mass:[Double],error:Double)
        do { mass=try StabilityInertiaEvidence.evaluate(s,position:q,supplier:inertia,policy:p,work:&massWork) }
        catch { try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(massWork,reservedStorage:s.reserve) };throw error }
        try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(massWork,reservedStorage:s.reserve) }
        let spectral=try StabilitySpectralEvidence.evaluate(s,mass:mass.mass,hessian:original.hessian,linear:linear,spectrum:spectrum,policy:p,work:&work)
        return Evidence(original:original,spectral:spectral,inertialError:mass.error)
    }
    private func coordinates(_ s: NonlinearStabilitySource, point: NonlinearStabilityPoint, policy p: NonlinearStabilityPolicy) -> [Double] {
        var result=[Double](repeating:0,count:s.dimension)
        for i in 0..<s.count { result[i]=point.position[i]/s.model.chart.scales[i] }
        for r in 0..<s.rowCount { result[s.count+r]=point.rowMultipliers[r] }
        result[s.dimension-1]=point.parameter/p.parameterScale
        return result
    }
    private func publish(_ s: NonlinearStabilitySource,z: [Double],data: Evidence,work: NumericalWork,policy p: NonlinearStabilityPolicy) -> NonlinearStabilityPoint {
        var q=[Double](repeating:0,count:s.count),mu=[Double](repeating:0,count:s.rowCount)
        for i in 0..<s.count { q[i]=z[i]*s.model.chart.scales[i] }
        for r in 0..<s.rowCount { mu[r]=z[s.count+r] }
        return NonlinearStabilityPoint(position:q,parameter:z[s.dimension-1]*p.parameterScale,energy:data.original.energy,
            physicalGradient:data.original.gradient,generalizedReaction:data.original.reaction,rowMultipliers:mu,
            originalForceResidual:data.original.balance,originalConstraintResidual:data.original.rows,originalArcResidual:data.original.arc,
            stiffnessEigenvalues:data.spectral.eigenvalues,modes:data.spectral.modes,reducedMass:data.spectral.mass,reducedStiffness:data.spectral.stiffness,
            maximumProjectedResidual:data.spectral.residual,maximumMassError:data.spectral.massError,
            maximumDerivativeError:data.original.derivativeError,maximumInertialError:data.inertialError,
            classification:data.spectral.classification,work:work)
    }
    @inline(never)
    private func refine(_ s: NonlinearStabilitySource,left: NonlinearStabilityState,right: NonlinearStabilityState,
                        policy p: NonlinearStabilityPolicy,work: inout NumericalWork) throws(Cause) -> NonlinearStabilityCriticalPoint {
        try admit(s,policy:p,work:&work)
        guard left.source===s,right.source===s,left.policy===p,right.policy===p,left.lineage===right.lineage else { throw .staleSource }
        guard right.precedingStepIdentity===left.stepIdentity,right.acceptedPoints==left.acceptedPoints+1,
            right.arcDistance>left.arcDistance,left.point.stiffnessEigenvalues[0]*right.point.stiffnessEigenvalues[0]<0 else { throw .noCriticalBracket }
        var a=coordinates(s,point:left.point,policy:p),b=coordinates(s,point:right.point,policy:p)
        var fa=left.point.stiffnessEigenvalues[0]
        for iteration in 1...p.maximumCriticalIterations {
            try StabilityArithmetic.check(p);try StabilityArithmetic.numerical { () throws(NumericalError) in try work.advanceIteration() }
            var direction=b,predictor=a
            for i in 0..<s.dimension { direction[i]-=a[i];predictor[i]=(a[i]+b[i])/2 }
            let width=StabilityArithmetic.norm(direction,source:s)
            guard width.isFinite,width>0 else { throw .unresolvedCriticalPoint }
            for i in direction.indices { direction[i]/=width }
            let z=try correct(s,predictor:predictor,direction:direction,initial:predictor,policy:p,work:&work)
            let data=try evidence(s,z:z,predictor:predictor,direction:direction,policy:p,work:&work)
            let f=data.spectral.eigenvalues[0]
            if abs(f)<=p.zeroStiffnessTolerance,width<=p.criticalWidth {
                guard data.spectral.eigenvalues.count>=2,abs(data.spectral.eigenvalues[1])>p.zeroStiffnessTolerance else { throw .degenerateCriticalPoint }
                var normalizedMode=[Double](repeating:0,count:s.count),norm=0.0
                for i in 0..<s.count { normalizedMode[i]=data.spectral.modes[i]/s.model.chart.scales[i];norm=ScalarMath.norm(norm,normalizedMode[i]) }
                guard norm.isFinite,norm>0 else { throw .invalidSupplierOutput }
                var projection=0.0
                for i in 0..<s.count { projection+=normalizedMode[i]/norm*s.model.chart.scales[i]*data.original.parameterDerivative[i]*p.parameterScale/s.model.energyScale }
                guard projection.isFinite else { throw .nonFiniteResult }
                try StabilityArithmetic.check(p)
                return NonlinearStabilityCriticalPoint(point:publish(s,z:z,data:data,work:work,policy:p),
                    kind:abs(projection)>p.loadProjectionTolerance ? .limitPointCandidate : .bifurcationCandidate,
                    bracketWidth:width,normalizedLoadProjection:projection,iterations:iteration,work:work)
            }
            if f*fa>0 { a=z;fa=f } else { b=z }
        }
        throw .unresolvedCriticalPoint
    }
}
