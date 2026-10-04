public struct PhysicalMassDamperIdentifier: PhysicalParameterIdentifying, Sendable {
    private let equations:any RigidEquationComputing
    private let derivatives:any MechanicalDifferentiating
    private let loads:any ScalarLoadEvaluating
    private let optimizer:any OptimizationSolving
    private let informationSolver:any LinearSolving<Double>
    public init(equations:any RigidEquationComputing = RigidEquationKernel(),derivatives:any MechanicalDifferentiating = ExactMechanicalDifferentiator(),
                loads:any ScalarLoadEvaluating = ScalarLoadEvaluator(),optimizer:any OptimizationSolving = CompleteConvexOptimizer(),
                informationSolver:any LinearSolving<Double> = ReferenceLinearSolver<Double>()) {
        self.equations=equations;self.derivatives=derivatives;self.loads=loads;self.optimizer=optimizer;self.informationSolver=informationSolver
    }
    @inline(never)
    public func estimate(_ p:PhysicalIdentificationProblem,policy:IdentificationPolicy,workspace:inout IdentificationWorkspace,
        loadWork:inout LoadWork,supplierWork:inout DerivativeSupplierWork,work:inout NumericalWork) throws(ParameterIdentificationFailure) -> PhysicalParameterEstimate {
        var context=IdentificationContext()
        do { return try run(p,policy:policy,workspace:&workspace,loadWork:&loadWork,supplierWork:&supplierWork,context:&context,work:&work) }
        catch { throw ParameterIdentificationFailure(cause:error,phase:context.phase,work:work,loadWork:loadWork,supplierWork:supplierWork,
            modelValidationAttempts:context.modelAttempts,lastOriginalResidual:context.residual,lastObjective:context.objective,failedSupplierWorkUnavailable:context.unavailable) }
    }
    @inline(never)
    private func run(_ p:PhysicalIdentificationProblem,policy:IdentificationPolicy,workspace s:inout IdentificationWorkspace,
        loadWork:inout LoadWork,supplierWork:inout DerivativeSupplierWork,context c:inout IdentificationContext,work:inout NumericalWork) throws(IdentificationCause) -> PhysicalParameterEstimate {
        try IdentificationAdmission.admit(p,policy,&s,&c,&work)
        c.phase = .physicalDesign
        let program=try build(p,policy:policy,workspace:&s,loadWork:&loadWork,supplierWork:&supplierWork,context:&c,work:&work)
        c.phase = .identifiability
        try IdentificationRank.prove(s.design,rows:p.observations.count,policy:policy,work:&work)
        c.phase = .optimization
        let result=try optimize(program,policy:policy,context:&c,work:&work)
        c.phase = .originalAcceptance
        let accepted=try IdentificationOriginalAcceptance.evaluate(p,result:result,design:s.design,offset:s.offset,equations:equations,derivatives:derivatives,loads:loads,
            policy:policy,physicalResiduals:&s.physicalResiduals,loadWork:&loadWork,supplierWork:&supplierWork,context:&c,work:&work)
        c.phase = .information
        let information=try IdentificationInformation.covariance(s.information,references:p.metadata.variableReferences,solver:informationSolver,policy:policy,context:&c,work:&work)
        s.covariance=information.0
        c.phase = .publication
        try IdentificationArithmetic.charge(try IdentificationArithmetic.sum(p.observations.count,24),policy,&work)
        try IdentificationArithmetic.check(policy)
        return PhysicalParameterEstimate(source:p.source,metadata:p.metadata,massKilograms:accepted.0[0],dampingNewtonSecondsPerMeter:accepted.0[1],
            lowerBounds:p.lowerBounds,upperBounds:p.upperBounds,objective:accepted.1,originalForceResidualsNewtons:s.physicalResiduals,
            normalizedInformationMatrix:s.information,unconstrainedGaussianReferenceCovariance:s.covariance,identifiableNormalizedDirections:[1,0,0,1],
            activeLowerBounds:accepted.3,activeUpperBounds:accepted.4,optimizationCertificate:accepted.2,originalGradient:accepted.5,
            originalStationarityResidual:accepted.6,originalInformationResidual:information.1,
            noiseAssumption:.independentGaussianForceNoiseKnownVarianceWithExactKinematics,work:work,loadWork:loadWork,supplierWork:supplierWork,modelValidationAttempts:c.modelAttempts)
    }
    @inline(never)
    private func build(_ p:PhysicalIdentificationProblem,policy:IdentificationPolicy,workspace s:inout IdentificationWorkspace,
        loadWork:inout LoadWork,supplierWork:inout DerivativeSupplierWork,context c:inout IdentificationContext,work:inout NumericalWork) throws(IdentificationCause) -> ConvexOptimizationProblem {
        let mass=p.source.referenceInertias[1].properties.mass,damping=p.lowerBounds[1]/2+p.upperBounds[1]/2
        let scales=p.metadata.variableReferences
        let x0=try IdentificationArithmetic.finite(mass/scales[0].magnitude),x1=try IdentificationArithmetic.finite(damping/scales[1].magnitude)
        var mechanics=MechanicalDerivativeWorkspace(),cost=[0.0,0.0],constant=0.0
        for i in p.observations.indices {
            let observation=p.observations[i]
            let physical=try MechanicalIdentificationSampling.sample(observation,source:p.source,mass:mass,damping:damping,equations:equations,derivatives:derivatives,loads:loads,
                policy:policy,workspace:&mechanics,loadWork:&loadWork,supplierWork:&supplierWork,context:&c,work:&work)
            try IdentificationArithmetic.charge(24,policy,&work)
            let sigma=observation.forceStandardDeviationNewtons
            let a=try IdentificationArithmetic.finite(physical.1*scales[0].magnitude/sigma),b=try IdentificationArithmetic.finite(physical.2*scales[1].magnitude/sigma)
            let offset=try IdentificationArithmetic.finite(physical.0/sigma-a*x0-b*x1)
            s.design[2*i]=a;s.design[2*i+1]=b;s.offset[i]=offset
            s.information[0]=try IdentificationArithmetic.finite(s.information[0]+a*a)
            s.information[1]=try IdentificationArithmetic.finite(s.information[1]+a*b)
            s.information[2]=s.information[1]
            s.information[3]=try IdentificationArithmetic.finite(s.information[3]+b*b)
            cost[0]=try IdentificationArithmetic.finite(cost[0]+a*offset);cost[1]=try IdentificationArithmetic.finite(cost[1]+b*offset)
            constant=try IdentificationArithmetic.finite(constant+0.5*offset*offset)
        }
        let hessian:DenseMatrix<Double>
        do { hessian=try DenseMatrix(rows:2,columns:2,values:s.information) } catch { throw .numerical(error) }
        return ConvexOptimizationProblem(metadata:p.metadata,linearCost:cost,constantCost:constant,hessian:hessian,
            lowerBounds:[p.lowerBounds[0]/scales[0].magnitude,p.lowerBounds[1]/scales[1].magnitude],
            upperBounds:[p.upperBounds[0]/scales[0].magnitude,p.upperBounds[1]/scales[1].magnitude])
    }
    @inline(never)
    private func optimize(_ p:ConvexOptimizationProblem,policy:IdentificationPolicy,context c:inout IdentificationContext,work:inout NumericalWork) throws(IdentificationCause) -> OptimizationResult {
        var nested=try IdentificationArithmetic.nested(work,reserved:c.reserved),workspace=EnumerationWorkspace()
        let before=nested
        var failure:OptimizationFailure?,result:OptimizationResult?
        do { result=try optimizer.solve(p,policy:policy.optimization,workspace:&workspace,work:&nested) } catch { failure=error }
        try IdentificationArithmetic.ledger(nested,before,reserved:c.reserved,&c,&work)
        try IdentificationArithmetic.absorb(nested,reserved:c.reserved,&work)
        if let failure { c.unavailable=c.unavailable || failure.failedSupplierWorkUnavailable;throw .optimization(failure) }
        guard let result else { throw .invalidSupplierOutput }
        return result
    }
}
