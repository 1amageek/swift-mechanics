/// Projected RK4/Heun evolution whose physical endpoint and history are published atomically.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ProjectedNonlinearMechanismEvolution: ProjectedMechanismEvolving, Sendable {
    public init() {}
    public func advance(_ session:any RuntimeSessionOperating,equations:NonlinearMechanismEquation,
                        continuation:IntegrationContinuationProvider,to time:Double) throws(NonlinearMechanismFailure) -> NonlinearMechanismAdvanceResult {
        try advance(session,equations:equations as any ProjectedMechanismEquations,continuation:continuation,to:time)
    }
    public func advance(_ session:any RuntimeSessionOperating,equations:any ProjectedMechanismEquations,
                        continuation:IntegrationContinuationProvider,to time:Double) throws(NonlinearMechanismFailure) -> NonlinearMechanismAdvanceResult {
        let context=NonlinearEvolutionRunContext(session:session,equations:equations,continuation:continuation,target:time)
        var progress=try Self.initialize(context)
        while progress.accepted.checkpoint.physical.time < time { progress=try Self.step(context,progress:progress) }
        return NonlinearMechanismAdvanceResult(requested:time,accepted:progress.accepted,steps:progress.steps,rejects:progress.rejects,work:progress.work,error:progress.error)
    }
    @inline(never)
    private static func initialize(_ context:NonlinearEvolutionRunContext) throws(NonlinearMechanismFailure) -> NonlinearEvolutionProgress {
        let accepted=context.session.snapshot()
        do throws(RuntimeFailure) {
            guard context.target.isFinite,context.target >= accepted.checkpoint.physical.time,context.continuation.descriptor == context.equations.descriptor,accepted.physical.stamp == context.equations.model.stamp else { throw RuntimeFailure(.invalidInput,message:"Projected nonlinear target/equation differs.") }
            try context.equations.validate(model:context.equations.model)
            guard let record=accepted.checkpoint.contributors.first(where:{$0.id == context.continuation.schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Nonlinear continuation missing.") }
            _=try context.continuation.associatedHistory(record,physical:accepted.checkpoint.physical,equations:context.equations)
        } catch { throw NonlinearMechanismFailure(cause:error,accepted:accepted,work:NonlinearMechanismWorkReport(),steps:0,rejects:0) }
        return NonlinearEvolutionProgress(accepted:accepted)
    }
    @inline(never)
    private static func step(_ context:NonlinearEvolutionRunContext,progress:NonlinearEvolutionProgress) throws(NonlinearMechanismFailure) -> NonlinearEvolutionProgress {
        let capture=NonlinearMechanismCapture()
        do throws(RuntimeFailure) {
            let attempt=try makeAttempt(context,progress:progress)
            return finish(try perform(context,attempt:attempt,capture:capture),progress:progress,evidence:capture.read())
        } catch {
            throw NonlinearMechanismFailure(cause:error,accepted:error.lastAccepted ?? context.session.snapshot(),
                work:progress.report(adding:capture.read(),unavailable:error.failedSupplierWorkUnavailable),steps:progress.steps,rejects:progress.rejects)
        }
    }
    @inline(never)
    private static func makeAttempt(_ context:NonlinearEvolutionRunContext,progress:NonlinearEvolutionProgress) throws(RuntimeFailure) -> NonlinearEvolutionAttemptContext {
        let policy=context.continuation.policy
        guard progress.attempts < policy.budget.maximumAttempts,progress.steps < policy.budget.maximumAcceptedSteps else { throw RuntimeFailure(.capacityExceeded,message:"Projected integration attempts exhausted.") }
        let budget:NumericalBudget
        do { budget=try NumericalBudget(scalarStorage:policy.budget.supplier.scalarStorage,arithmeticOperations:policy.budget.supplier.arithmeticOperations-progress.work.supplierArithmeticCharged,iterations:policy.budget.supplier.iterations-progress.work.supplierIterationsCharged) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Projected supplier aggregate budget exhausted.") }
        return NonlinearEvolutionAttemptContext(equations:context.equations,continuation:context.continuation,expected:progress.accepted,target:context.target,retry:progress.retry,budget:budget,outerRemaining:policy.budget.maximumOuterArithmetic-progress.work.outerArithmeticBoundCharged)
    }
    @inline(never)
    private static func perform(_ context:NonlinearEvolutionRunContext,attempt:NonlinearEvolutionAttemptContext,capture:NonlinearMechanismCapture) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        try context.session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
            try Self.attempt(attempt,trial:&trial,control:control,capture:capture)
        }
    }
    @inline(never)
    private static func finish(_ outcome:RuntimeTrialOutcome,progress:NonlinearEvolutionProgress,evidence:NonlinearMechanismAttempt) -> NonlinearEvolutionProgress {
        let rejected=outcome.decision == .reject
        return NonlinearEvolutionProgress(accepted:outcome.accepted,steps:progress.steps+(rejected ? 0 : 1),rejects:progress.rejects+(rejected ? 1 : 0),
            attempts:progress.attempts+1,work:progress.report(adding:evidence),retry:rejected ? evidence.nextStep : nil,error:evidence.error)
    }
    @inline(never)
    private static func attempt(_ context:NonlinearEvolutionAttemptContext,trial:inout RuntimeTrial,
                                control:RuntimeStepControl,capture:NonlinearMechanismCapture) throws(RuntimeFailure) -> RuntimeTrialDecision {
        let n=context.equations.descriptor.dimensions.count
        guard n <= context.continuation.policy.budget.maximumCoordinates else { throw RuntimeFailure(.capacityExceeded,message:"Projected coordinate capacity exhausted.") }
        var workspace=try NonlinearEvolutionWorkspace(count:n,budget:context.budget,maximumOuter:context.outerRemaining)
        defer { capture.store(workspace.evidence) }
        do throws(RuntimeFailure) {
            let interval=try prepare(context,trial:&trial,workspace:&workspace,control:control)
            try stages(context,interval:interval,workspace:&workspace,control:control)
            guard try assess(context,interval:interval,workspace:&workspace) else { return .reject }
            return try publish(context,interval:interval,workspace:&workspace,trial:&trial,control:control)
        } catch { workspace.unavailable=error.failedSupplierWorkUnavailable;throw error }
    }
    @inline(never)
    private static func prepare(_ context:NonlinearEvolutionAttemptContext,trial:inout RuntimeTrial,
                                workspace:inout NonlinearEvolutionWorkspace,control:RuntimeStepControl) throws(RuntimeFailure) -> NonlinearEvolutionInterval {
        try workspace.charge(1,control:control)
        let record=try trial.contributor(context.continuation.schema.id),history=try context.continuation.history(record)
        guard record == context.expected.checkpoint.contributors.first(where:{$0.id == context.continuation.schema.id}),trial.timeSeconds == history.acceptedTime else { throw RuntimeFailure(.invalidOwnerAccess,message:"Projected accepted association changed.") }
        try context.equations.read(trial,into:&workspace.start)
        guard workspace.start == history.acceptedPoint else { throw RuntimeFailure(.invalidContributor,message:"Projected history does not match physical chart.") }
        try context.equations.validateInitial(time:history.acceptedTime,point:workspace.start,work:&workspace.work,control:control)
        let t=history.acceptedTime,h=min(context.retry ?? history.nextStep,context.target-t),end=h == context.target-t ? context.target : t+h
        guard h.isFinite,h > 0,end.isFinite,end > t,end <= context.target else { throw RuntimeFailure(.invalidInput,message:"Projected step cannot advance time.") }
        return NonlinearEvolutionInterval(time:t,step:h,end:end,acceptedSteps:history.acceptedSteps)
    }
    @inline(never)
    private static func stages(_ context:NonlinearEvolutionAttemptContext,interval:NonlinearEvolutionInterval,
                               workspace w:inout NonlinearEvolutionWorkspace,control:RuntimeStepControl) throws(RuntimeFailure) {
        let equations=context.equations,policy=context.continuation.policy,n=w.start.count,t=interval.time,h=interval.step,end=interval.end
        w.calls+=1;try equations.derivative(time:t,point:w.start,into:&w.k1,work:&w.work,control:control)
        if policy.method == .classicalRK4 {
            for i in 0..<n { try w.charge(4,control:control);w.stage[i]=w.start[i]+h*w.k1[i]/2 }
            w.calls+=1;try equations.derivative(time:t+h/2,point:w.stage,into:&w.k2,work:&w.work,control:control)
            for i in 0..<n { try w.charge(4,control:control);w.stage[i]=w.start[i]+h*w.k2[i]/2 }
            w.calls+=1;try equations.derivative(time:t+h/2,point:w.stage,into:&w.k3,work:&w.work,control:control)
            for i in 0..<n { try w.charge(3,control:control);w.stage[i]=w.start[i]+h*w.k3[i] }
            w.calls+=1;try equations.derivative(time:end,point:w.stage,into:&w.k4,work:&w.work,control:control)
            for i in 0..<n { try w.charge(10,control:control);w.result[i]=w.start[i]+h*(w.k1[i]+2*w.k2[i]+2*w.k3[i]+w.k4[i])/6 }
        } else {
            for i in 0..<n { try w.charge(3,control:control);w.stage[i]=w.start[i]+h*w.k1[i] }
            w.calls+=1;try equations.derivative(time:end,point:w.stage,into:&w.k2,work:&w.work,control:control)
            var norm=0.0
            for i in 0..<n {
                try w.charge(20,control:control);w.result[i]=w.start[i]+h*(w.k1[i]+w.k2[i])/2
                let scale=policy.scales[i].absoluteSI+policy.scales[i].relative*max(abs(w.start[i]),abs(w.result[i]))
                norm=max(norm,abs(w.result[i]-w.stage[i])/scale)
            }
            guard norm.isFinite else { throw RuntimeFailure(.invalidState,message:"Projected adaptive error is nonfinite.") }
            w.error=norm
        }
    }
    @inline(never)
    private static func assess(_ context:NonlinearEvolutionAttemptContext,interval:NonlinearEvolutionInterval,
                               workspace:inout NonlinearEvolutionWorkspace) throws(RuntimeFailure) -> Bool {
        let policy=context.continuation.policy
        if policy.method == .classicalRK4 { workspace.next=policy.initialStep;return true }
        guard let norm=workspace.error else { throw RuntimeFailure(.invalidState,message:"Projected adaptive error is unavailable.") }
        let factor=norm == 0 ? policy.maximumFactor : min(policy.maximumFactor,max(policy.minimumFactor,policy.safety/norm.squareRoot()))
        let proposal=interval.step*factor
        guard proposal.isFinite,proposal > 0 else { throw RuntimeFailure(.invalidState,message:"Projected adaptive proposal is invalid.") }
        if norm > 1 {
            guard proposal < interval.step,proposal >= policy.minimumStep else { throw RuntimeFailure(.capacityExceeded,message:"Projected minimum step exhausted.") }
            workspace.next=min(policy.maximumStep,proposal);return false
        }
        workspace.next=min(policy.maximumStep,max(policy.minimumStep,proposal));return true
    }
    @inline(never)
    private static func publish(_ context:NonlinearEvolutionAttemptContext,interval:NonlinearEvolutionInterval,
                                workspace:inout NonlinearEvolutionWorkspace,trial:inout RuntimeTrial,control:RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision {
        let equations=context.equations,end=interval.end
        workspace.result=try projectedEndpoint(equations,time:end,point:workspace.result,work:&workspace.work,control:control)
        // Recompute the final derivative at the exact endpoint; projection temporaries ended in the preceding phase.
        workspace.calls+=1;try equations.derivative(time:end,point:workspace.result,into:&workspace.stage,work:&workspace.work,control:control)
        try equations.validateInitial(time:end,point:workspace.result,work:&workspace.work,control:control)
        try equations.writeAccepted(point:workspace.result,derivative:workspace.stage,time:end,trial:&trial,work:&workspace.work,control:control)
        try equations.read(trial,into:&workspace.k1)
        guard workspace.k1 == workspace.result,trial.timeSeconds == end,interval.acceptedSteps < UInt64.max,let next=workspace.next else { throw RuntimeFailure(.invalidState,message:"Projected endpoint/time/history publication differs.") }
        try trial.replaceContributor(context.continuation.record(acceptedTime:end,point:workspace.result,nextStep:next,acceptedSteps:interval.acceptedSteps+1,normalizedError:workspace.error));return .accept
    }
    @inline(never)
    private static func projectedEndpoint(_ equations:any ProjectedMechanismEquations,time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> [Double] {
        try equations.consistent(time:time,point:point,work:&work,control:control).point
    }
}
