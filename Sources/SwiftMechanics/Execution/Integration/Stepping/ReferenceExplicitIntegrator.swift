
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceExplicitIntegrator: ExplicitIntegrating, Sendable {
    public init() {}
    public func advance(_ session: any RuntimeSessionOperating, model: CompiledMechanicalModel, equations: any SmoothODEEquations,
                        continuation: IntegrationContinuationProvider, to requestedTime: Double) throws(IntegrationFailure) -> IntegrationAdvanceResult {
        try run(session, model: model, equations: equations, continuation: continuation, target: requestedTime, firstOnly: false)
    }
    public func step(_ session: any RuntimeSessionOperating, model: CompiledMechanicalModel, equations: any SmoothODEEquations,
                     continuation: IntegrationContinuationProvider) throws(IntegrationFailure) -> IntegrationAdvanceResult {
        let accepted = session.snapshot()
        let target: Double
        do throws(RuntimeFailure) {
            guard let record = accepted.checkpoint.contributors.first(where: { $0.id == continuation.schema.id }) else { throw RuntimeFailure(.missingContributor, message: "Required integration history is missing.") }
            let history = try continuation.history(record)
            target = history.acceptedTime + history.nextStep
        } catch { throw IntegrationFailure(cause: error, accepted: accepted, work: IntegrationWorkReport(unavailable: error.failedSupplierWorkUnavailable), steps: 0, rejects: 0) }
        return try run(session, model: model, equations: equations, continuation: continuation, target: target, firstOnly: true)
    }
    private func run(_ session: any RuntimeSessionOperating, model: CompiledMechanicalModel, equations: any SmoothODEEquations,
                     continuation: IntegrationContinuationProvider, target: Double, firstOnly: Bool) throws(IntegrationFailure) -> IntegrationAdvanceResult {
        var accepted = session.snapshot(), steps = 0, rejects = 0, attempts = 0
        var outer = 0, supplier = 0, calls = 0, slots = 0, iterations = 0, supplierSlots = 0
        var unavailable = false
        var lastError: Double?, retryStep: Double?
        let policy = continuation.policy, descriptor = continuation.descriptor
        func report() -> IntegrationWorkReport { IntegrationWorkReport(outer: outer, supplier: supplier, calls: calls, scalars: slots, iterations: iterations, supplierScalars: supplierSlots, unavailable: unavailable) }
        do throws(RuntimeFailure) {
            guard target.isFinite, target >= accepted.checkpoint.physical.time, equations.descriptor == descriptor,
                  model.stamp == descriptor.model, accepted.physical.stamp == model.stamp else { throw RuntimeFailure(.invalidInput, message: "Target/model/equation binding is invalid.") }
            try equations.validate(model: model)
            guard let record = accepted.checkpoint.contributors.first(where: { $0.id == continuation.schema.id }) else { throw RuntimeFailure(.missingContributor, message: "Required integration history is missing.") }
            _ = try continuation.associatedHistory(record, physical: accepted.checkpoint.physical, equations: equations)
            guard equations.descriptor == descriptor else { throw RuntimeFailure(.invalidInput, message: "Equation descriptor changed during model validation.") }
        } catch { unavailable = unavailable || error.failedSupplierWorkUnavailable; throw IntegrationFailure(cause: error, accepted: accepted, work: report(), steps: steps, rejects: rejects) }
        while accepted.checkpoint.physical.time < target {
            let capture = IntegrationAttemptCapture(), expected = accepted
            var consumed = false
            do throws(RuntimeFailure) {
                guard attempts < policy.budget.maximumAttempts, steps < policy.budget.maximumAcceptedSteps else { throw RuntimeFailure(.capacityExceeded, message: "Integration attempt/accepted-step budget exhausted.") }
                attempts += 1
                let supplierBudget: NumericalBudget
                do { supplierBudget = try NumericalBudget(scalarStorage: policy.budget.supplier.scalarStorage,
                        arithmeticOperations: policy.budget.supplier.arithmeticOperations - supplier, iterations: policy.budget.supplier.iterations - iterations) }
                catch { throw RuntimeFailure(.capacityExceeded, message: "Supplier integration budget exhausted.") }
                let context = IntegrationAttemptContext(equations: equations, continuation: continuation, expected: expected,
                    target: target, retry: retryStep, supplierBudget: supplierBudget, outerRemaining: policy.budget.maximumOuterArithmetic - outer)
                let outcome = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                    try Self.executeTrial(context, trial: &trial, control: control, capture: capture)
                }
                unavailable = unavailable || capture.read().work.failedSupplierWorkUnavailable
                consumed = true
                let evidence = capture.read(); outer += evidence.work.outerArithmeticBoundCharged; supplier += evidence.work.supplierArithmeticCharged
                calls += evidence.work.derivativeCalls; iterations += evidence.work.supplierIterationsCharged; supplierSlots = max(supplierSlots,evidence.work.peakSupplierScalars); slots = max(slots,evidence.work.reservedCoordinateScalars); lastError = evidence.error
                accepted = outcome.accepted
                if outcome.decision == .reject {
                    rejects += 1
                    guard let next = evidence.nextStep else { throw RuntimeFailure(.invalidState, message: "Rejected step has no explicit retry proposal.") }; retryStep = next
                } else {
                    steps += 1; retryStep = nil
                    if firstOnly { break }
                }
            } catch {
                let evidence = capture.read(); unavailable = unavailable || evidence.work.failedSupplierWorkUnavailable || error.failedSupplierWorkUnavailable
                if !consumed { outer += evidence.work.outerArithmeticBoundCharged; supplier += evidence.work.supplierArithmeticCharged; calls += evidence.work.derivativeCalls; iterations += evidence.work.supplierIterationsCharged; supplierSlots = max(supplierSlots,evidence.work.peakSupplierScalars) }
                slots = max(slots,evidence.work.reservedCoordinateScalars)
                throw IntegrationFailure(cause: error, accepted: error.lastAccepted ?? session.snapshot(), work: report(), steps: steps, rejects: rejects)
            }
        }
        return IntegrationAdvanceResult(requested: target, accepted: accepted, steps: steps, rejects: rejects, work: report(), error: lastError)
    }
    @inline(never)
    private static func executeTrial(_ context: IntegrationAttemptContext, trial: inout RuntimeTrial,
                                     control: RuntimeStepControl, capture: IntegrationAttemptCapture) throws(RuntimeFailure) -> RuntimeTrialDecision {
        var workspace = try IntegrationStageWorkspace(count: context.continuation.descriptor.dimensions.count,
            maximumOuter: context.outerRemaining, supplier: context.supplierBudget)
        var error: Double?, next: Double?
        defer { capture.store(IntegrationAttemptEvidence(work: workspace.report, error: error, next: next)) }
        let interval = try prepareTrial(context, trial: &trial, workspace: &workspace, control: control)
        try stages(context, interval: interval, workspace: &workspace, control: control)
        guard try assessStep(context, interval: interval, workspace: &workspace, error: &error, next: &next, control: control) else { return .reject }
        return try publishEndpoint(context, interval: interval, workspace: &workspace, error: error, next: next, trial: &trial, control: control)
    }
    @inline(never)
    private static func prepareTrial(_ context: IntegrationAttemptContext, trial: inout RuntimeTrial,
                                     workspace: inout IntegrationStageWorkspace, control: RuntimeStepControl) throws(RuntimeFailure) -> IntegrationTrialInterval {
        let equations = context.equations, continuation = context.continuation, expected = context.expected
        let descriptor = continuation.descriptor
        let n = descriptor.dimensions.count, target = context.target, retry = context.retry
        try control.beginWorkBlock(units: 1)
        guard equations.descriptor == descriptor else { throw RuntimeFailure(.invalidInput, message: "Equation descriptor changed before trial.") }
        let record = try trial.contributor(continuation.schema.id), history = try continuation.history(record)
        guard let expectedRecord = expected.checkpoint.contributors.first(where: { $0.id == continuation.schema.id }), record == expectedRecord,
              trial.timeSeconds == expected.checkpoint.physical.time, history.acceptedTime == trial.timeSeconds else { throw RuntimeFailure(.invalidOwnerAccess, message: "Accepted integration association changed between transactions.") }
        try control.beginWorkBlock(units: 1)
        try equations.read(trial, into: &workspace.start)
        guard workspace.start.count == n, workspace.start == history.acceptedPoint, workspace.start.allSatisfy({ $0.isFinite }) else { throw RuntimeFailure(.invalidContributor, message: "History does not match actual trial chart state.") }
        try control.beginWorkBlock(units: 1)
        try Self.supplierCall(work: &workspace.supplier, unavailable: &workspace.unavailable) { work throws(RuntimeFailure) in
            try equations.prepare(trial: &trial, work: &work, control: control)
        }
        try equations.read(trial, into: &workspace.stage)
        guard workspace.stage == workspace.start, trial.timeSeconds == history.acceptedTime else { throw RuntimeFailure(.invalidState, message: "Subsystem preparation changed physical chart/time.") }
        let time = trial.timeSeconds, requested = retry ?? history.nextStep, gap = target - time
        let h = min(requested, gap), end = h == gap ? target : time + h
        guard h.isFinite, h > 0, end.isFinite, end > time, end <= target else { throw RuntimeFailure(.invalidInput, message: "Step cannot advance representable accepted time.") }
        return IntegrationTrialInterval(time: time, step: h, end: end, acceptedSteps: history.acceptedSteps)
    }
    @inline(never)
    private static func assessStep(_ context: IntegrationAttemptContext, interval: IntegrationTrialInterval,
                                   workspace: inout IntegrationStageWorkspace, error: inout Double?, next: inout Double?,
                                   control: RuntimeStepControl) throws(RuntimeFailure) -> Bool {
        let policy = context.continuation.policy, n = context.continuation.descriptor.dimensions.count, h = interval.step
        if policy.method == .heunEuler {
            var norm = 0.0
            for i in 0..<n {
                try workspace.charge(32, control: control)
                let scale = policy.scales[i].absoluteSI + policy.scales[i].relative * max(abs(workspace.start[i]), abs(workspace.result[i]))
                let difference = abs(workspace.result[i] - (workspace.start[i] + h*workspace.k1[i]))
                guard scale.isFinite, scale > 0, difference.isFinite else { throw RuntimeFailure(.invalidState, message: "Dimensional integration error norm overflow.") }
                norm = max(norm, difference / scale)
            }
            guard norm.isFinite else { throw RuntimeFailure(.invalidState, message: "Normalized integration error is nonfinite.") }
            error = norm
            let factor = norm == 0 ? policy.maximumFactor : min(policy.maximumFactor,max(policy.minimumFactor,policy.safety/norm.squareRoot()))
            let proposal = h*factor
            guard proposal.isFinite, proposal > 0 else { throw RuntimeFailure(.invalidState, message: "Adaptive step proposal overflow/underflow.") }
            if norm > 1 {
                guard proposal < h, proposal >= policy.minimumStep else { throw RuntimeFailure(.capacityExceeded, message: "Adaptive error target exhausted minimum step.") }
                next = min(policy.maximumStep,proposal); return false
            }
            next = min(policy.maximumStep,max(policy.minimumStep,proposal))
        } else { next = policy.initialStep }
        return true
    }
    @inline(never)
    private static func publishEndpoint(_ context: IntegrationAttemptContext, interval: IntegrationTrialInterval,
                                        workspace: inout IntegrationStageWorkspace, error: Double?, next: Double?,
                                        trial: inout RuntimeTrial, control: RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision {
        let equations = context.equations, continuation = context.continuation
        let descriptor = continuation.descriptor, end = interval.end
        guard interval.acceptedSteps < UInt64.max else { throw RuntimeFailure(.integerOverflow, message: "Accepted integration sequence overflow.") }
        // Endpoint derivative is real and provider publication has no inferred q/v meaning.
        try Self.evaluate(equations, descriptor: descriptor, time: end, point: workspace.result, output: &workspace.stage, supplier: &workspace.supplier, unavailable: &workspace.unavailable, outer: &workspace.outer,
                          maximumOuter: workspace.maximumOuter, calls: &workspace.calls, control: control)
        try control.beginWorkBlock(units: 1)
        try equations.write(point: workspace.result, derivative: workspace.stage, time: end, trial: &trial)
        try control.beginWorkBlock(units: 1)
        try equations.read(trial, into: &workspace.k1)
        guard trial.timeSeconds == end, workspace.k1 == workspace.result, equations.descriptor == descriptor else { throw RuntimeFailure(.invalidState, message: "Chart publication did not preserve endpoint/time/descriptor.") }
        guard let next else { throw RuntimeFailure(.invalidState, message: "Accepted step has no continuation proposal.") }
        let updated = IntegrationHistory(time: end, point: workspace.result, nextStep: next, steps: interval.acceptedSteps + 1, error: error)
        try trial.replaceContributor(continuation.record(updated)); return .accept
    }
    private static func supplierCall(work: inout NumericalWork, unavailable: inout Bool,
                                     _ operation: (inout NumericalWork) throws(RuntimeFailure) -> Void) throws(RuntimeFailure) {
        let previous = work
        var failure: RuntimeFailure?
        do throws(RuntimeFailure) { try operation(&work) } catch { failure = error }
        guard work.budget.scalarStorage == previous.budget.scalarStorage,
              work.budget.arithmeticOperations == previous.budget.arithmeticOperations, work.budget.iterations == previous.budget.iterations,
              work.operations >= previous.operations, work.iterations >= previous.iterations, work.peakScalarStorage >= previous.peakScalarStorage else {
            work = previous; unavailable = true
            throw RuntimeFailure(.invalidOwnerAccess, message: "Supplier replaced/reset the authoritative numerical budget ledger.", failedSupplierWorkUnavailable: true)
        }
        if let failure { unavailable = unavailable || failure.failedSupplierWorkUnavailable; throw failure }
    }
    private static func evaluate(_ equations: any SmoothODEEquations, descriptor: ODEDescriptor, time: Double, point: [Double],
                                 output: inout [Double], supplier: inout NumericalWork, unavailable: inout Bool, outer: inout Int, maximumOuter: Int,
                                 calls: inout Int, control: RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units: 1)
        guard time.isFinite, point.count == descriptor.dimensions.count, point.allSatisfy({ $0.isFinite }), output.count == point.count,
              equations.descriptor == descriptor else { throw RuntimeFailure(.invalidState, message: "Derivative input/descriptor is invalid.") }
        for i in output.indices { try control.beginWorkBlock(units: 1); output[i] = .nan }
        calls += 1
        try supplierCall(work: &supplier, unavailable: &unavailable) { work throws(RuntimeFailure) in
            try equations.derivative(time: time, point: point, into: &output, work: &work, control: control)
        }
        try control.beginWorkBlock(units: 1)
        guard equations.descriptor == descriptor, output.count == point.count, output.allSatisfy({ $0.isFinite }) else { throw RuntimeFailure(.invalidState, message: "Derivative output is incomplete/nonfinite or descriptor changed.") }
    }
    @inline(never)
    private static func stages(_ context: IntegrationAttemptContext, interval: IntegrationTrialInterval,
                               workspace w: inout IntegrationStageWorkspace, control: RuntimeStepControl) throws(RuntimeFailure) {
        let equations = context.equations, descriptor = context.continuation.descriptor, policy = context.continuation.policy
        let time = interval.time, h = interval.step, endpoint = interval.end
        try evaluate(equations, descriptor: descriptor, time: time, point: w.start, output: &w.k1, supplier: &w.supplier, unavailable: &w.unavailable, outer: &w.outer, maximumOuter: w.maximumOuter, calls: &w.calls, control: control)
        if policy.method == .heunEuler {
            for i in w.start.indices { try w.charge(32,control: control); w.stage[i] = w.start[i] + h*w.k1[i] }
            try evaluate(equations, descriptor: descriptor, time: endpoint, point: w.stage, output: &w.k2, supplier: &w.supplier, unavailable: &w.unavailable, outer: &w.outer, maximumOuter: w.maximumOuter, calls: &w.calls, control: control)
            for i in w.start.indices { try w.charge(32,control: control); w.result[i] = w.start[i] + h*(w.k1[i]+w.k2[i])/2 }
        } else {
            for i in w.start.indices { try w.charge(32,control: control); w.stage[i] = w.start[i] + h*w.k1[i]/2 }
            try evaluate(equations, descriptor: descriptor, time: time+h/2, point: w.stage, output: &w.k2, supplier: &w.supplier, unavailable: &w.unavailable, outer: &w.outer, maximumOuter: w.maximumOuter, calls: &w.calls, control: control)
            for i in w.start.indices { try w.charge(32,control: control); w.stage[i] = w.start[i] + h*w.k2[i]/2 }
            try evaluate(equations, descriptor: descriptor, time: time+h/2, point: w.stage, output: &w.k3, supplier: &w.supplier, unavailable: &w.unavailable, outer: &w.outer, maximumOuter: w.maximumOuter, calls: &w.calls, control: control)
            for i in w.start.indices { try w.charge(32,control: control); w.stage[i] = w.start[i] + h*w.k3[i] }
            try evaluate(equations, descriptor: descriptor, time: endpoint, point: w.stage, output: &w.k4, supplier: &w.supplier, unavailable: &w.unavailable, outer: &w.outer, maximumOuter: w.maximumOuter, calls: &w.calls, control: control)
            for i in w.start.indices { try w.charge(32,control: control); w.result[i] = w.start[i] + h*(w.k1[i]+2*w.k2[i]+2*w.k3[i]+w.k4[i])/6 }
        }
        guard w.result.allSatisfy({ $0.isFinite }) else { throw RuntimeFailure(.invalidState, message: "Integration stage arithmetic produced nonfinite endpoint.") }
    }
}
