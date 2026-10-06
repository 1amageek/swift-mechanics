public struct FixedActiveLocalOptimizer: LocalOptimizationSolving, Sendable {
    private let nonlinear: any NonlinearSolving<Double>,linear: any LinearSolving<Double>
    public init(nonlinear: any NonlinearSolving<Double> = ReferenceNonlinearSolver<Double>(),linear: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) {
        self.nonlinear=nonlinear; self.linear=linear
    }
    @inline(never)
    public func solve(_ p: FixedActiveNonlinearProblem,policy: LocalOptimizationPolicy,work: inout NumericalWork) throws(LocalOptimizationFailure) -> StrictLocalOptimum {
        var context=LocalKKTContext()
        do { return try run(p,policy:policy,context:&context,work:&work) }
        catch { throw LocalOptimizationFailure(cause:error,phase:context.phase,work:work,unavailable:context.unavailable,residual:context.residual) }
    }
    @inline(never)
    private func run(_ p: FixedActiveNonlinearProblem,policy: LocalOptimizationPolicy,context: inout LocalKKTContext,work: inout NumericalWork) throws(LocalOptimizationCause) -> StrictLocalOptimum {
        let (layout,reserved)=try LocalKKTAdmission.admit(p,policy:policy,work:&work)
        context.reserved=reserved
        do { try policy.nonlinear.capability.validate(for:Double.self,algorithms:[.partialPivotLU]); try policy.curvatureCapability.validate(for:Double.self,algorithms:[.cholesky]) }
        catch { throw .numerical(error) }
        let equations=FixedActiveKKTEquations<Double>(provider:p.provider,layout:layout,lower:p.lowerBounds,upper:p.upperBounds,active:p.activeInequalities,scratch:policy.maximumProviderScratchScalars,cancelled:policy.isCancelled)
        let z=try nonlinearPoint(p,equations:equations,policy:policy,context:&context,work:&work)
        let certificate=try OriginalLocalCertificate.assess(z,equations:equations,policy:policy,context:&context,work:&work)
        context.phase = .rank
        let nullspace=try LocalNullspace.build(certificate.activeJacobian,rows:layout.equalityCount+p.activeInequalities.count,n:layout.variableCount,policy:policy,work:&work)
        let reduced=try ReducedLocalCurvature.prove(certificate,nullspace:nullspace,equations:equations,linear:linear,policy:policy,context:&context,work:&work)
        return try publish(certificate,nullspace:nullspace,reduced:reduced,layout:layout,problem:p,policy:policy,context:&context,work:&work)
    }
    @inline(never)
    private func nonlinearPoint(_ p: FixedActiveNonlinearProblem,equations q: FixedActiveKKTEquations<Double>,policy: LocalOptimizationPolicy,context: inout LocalKKTContext,work: inout NumericalWork) throws(LocalOptimizationCause) -> [Double] {
        context.phase = .nonlinearSolve
        try LocalKKTArithmetic.charge(q.coordinateCount,policy:policy,work:&work)
        var initial=p.initialPoint; initial.append(contentsOf:p.initialEqualityMultipliers); initial.append(contentsOf:p.initialActiveMultipliers)
        let requested: NonlinearPolicy<Double>
        do {
            let remaining=try work.remainingBudget(reservedStorage:context.reserved),t=policy.nonlinear
            let budget=try NumericalBudget(scalarStorage:min(remaining.scalarStorage,t.budget.scalarStorage),arithmeticOperations:min(remaining.arithmeticOperations,t.budget.arithmeticOperations),iterations:min(remaining.iterations,t.budget.iterations))
            requested=try NonlinearPolicy(strategy:t.strategy,capability:t.capability,tolerance:t.tolerance,referenceScale:t.referenceScale,minimumDirectionNorm:t.minimumDirectionNorm,
                derivativeProbeDistance:t.derivativeProbeDistance,derivativeAbsoluteTolerance:t.derivativeAbsoluteTolerance,derivativeRelativeTolerance:t.derivativeRelativeTolerance,
                maximumFactorEntries:t.maximumFactorEntries,estimateCondition:t.estimateCondition,budget:budget)
        } catch { throw .numerical(error) }
        let solved: NonlinearSolution<Double>
        do { solved=try nonlinear.solve(q,initialPoint:initial,policy:requested) }
        catch {
            context.unavailable=error.failedSupplierWorkUnavailable || KKTArithmetic.ledgerUnavailable(error.cause)
            guard error.work.budget == requested.budget else { context.unavailable=true; throw .invalidSupplierLedger }
            do { try work.absorb(error.work,reservedStorage:context.reserved) } catch { throw .numerical(error) }
            throw .nonlinear(error)
        }
        guard solved.diagnostics.work.budget == requested.budget else { context.unavailable=true; throw .invalidSupplierLedger }
        do { try work.absorb(solved.diagnostics.work,reservedStorage:context.reserved) } catch { throw .numerical(error) }
        guard solved.values.count == q.coordinateCount,solved.values.allSatisfy({ $0.isFinite }),solved.internalResidual.isAccepted,solved.originalResidual.isAccepted else { throw .invalidSupplierOutput }
        return solved.values
    }
    @inline(never)
    private func publish(_ c: LocalCertificateState,nullspace z: LocalNullspace,reduced: [Double],layout l: NonlinearProgramLayout,problem p: FixedActiveNonlinearProblem,
        policy: LocalOptimizationPolicy,context: inout LocalKKTContext,work: inout NumericalWork) throws(LocalOptimizationCause) -> StrictLocalOptimum {
        context.phase = .publication
        guard p.provider.layout === l else { throw .callback(.equationMetadataChanged) }
        let n=l.variableCount,m=l.inequalityCount
        try LocalKKTArithmetic.charge(4*n+m+1,policy:policy,work:&work)
        var physical=[Double](repeating:0,count:n),lower=physical,upper=physical,user=[Double](repeating:0,count:m)
        for i in 0..<n { physical[i]=try LocalKKTArithmetic.finite(c.point[i]*l.metadata.variableReferences[i].magnitude); lower[i]=c.inequalities[m+2*i]; upper[i]=c.inequalities[m+2*i+1] }
        for i in 0..<m { user[i]=c.inequalities[i] }
        let physicalObjective=try LocalKKTArithmetic.finite(c.values.objective*l.metadata.objectiveReference.magnitude)
        let proof=LocalKKTProof(primalResidual:c.primal,dualResidual:c.dual,stationarityResidual:c.stationarity,complementarityResidual:c.complementarity,
            primalThreshold:c.primalThreshold,dualThreshold:c.dualThreshold,stationarityThreshold:c.stationarityThreshold,complementarityThreshold:c.complementarityThreshold,
            activeRank:l.equalityCount+p.activeInequalities.count,tangentDimension:z.dimension,nullspaceResidual:z.residual,nullspaceBasis:z.basis,reducedLagrangianHessian:reduced)
        do { try KKTArithmetic.check(policy.isCancelled) } catch { throw .callback(error) }
        return StrictLocalOptimum(metadata:l.metadata,point:c.point,objective:c.values.objective,physicalPoint:physical,physicalObjective:physicalObjective,
            equalityMultipliers:c.equalities,inequalityMultipliers:user,lowerMultipliers:lower,upperMultipliers:upper,activeInequalities:p.activeInequalities,proof:proof,work:work)
    }
}
