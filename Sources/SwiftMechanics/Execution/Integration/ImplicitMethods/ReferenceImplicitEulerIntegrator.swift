@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceImplicitEulerIntegrator: ImplicitEulerIntegrating, Sendable {
    public init() {}

    public func step(_ session: any RuntimeSessionOperating, model: CompiledMechanicalModel,
                     equations: any ImplicitODEEquations, to time: Double,
                     policy: ImplicitEulerPolicy) throws(ImplicitIntegrationFailure) -> ImplicitEulerStepResult {
        let expected = session.snapshot(), descriptor = equations.descriptor
        let capture = ImplicitAttemptCapture(budget: policy.nonlinear.budget)
        var initialWork = NumericalWork(budget: policy.nonlinear.budget)
        let start: [Double], scales: [Double], retained: Int, entries: Int
        do throws(ImplicitMethodCause) {
            guard !Task.isCancelled else { throw .numerical(.cancelled) }
            guard equations.implicitDomain == .smoothEuclidean else { throw .unsupportedDomain }
            guard descriptor.model == model.stamp, expected.physical.stamp == model.stamp,
                  time.isFinite, time > expected.checkpoint.physical.time,
                  (time-expected.checkpoint.physical.time).isFinite,
                  descriptor.dimensions.count == policy.scales.count else { throw .invalidInput }
            // An explicit contributor encodes another method's continuation and cannot be retained stale.
            guard !expected.checkpoint.contributors.contains(where: { $0.category == .integrator }) else { throw .unsupportedDomain }
            do throws(RuntimeFailure) { try equations.validate(model: model) }
            catch { throw .runtime(error) }
            guard equations.descriptor == descriptor, equations.implicitDomain == .smoothEuclidean else { throw .invalidEvaluation }
            let n = descriptor.dimensions.count
            do throws(NumericalError) {
                entries = try NumericalWork.product(n,n)
                retained = try NumericalWork.sum(entries, NumericalWork.product(8,n))
                try initialWork.requireStorage(retained)
                try initialWork.chargeOperations(try NumericalWork.product(8,n))
            } catch { throw .numerical(error) }
            var point = [Double](repeating: .nan, count: n)
            do throws(RuntimeFailure) { try equations.read(expected.checkpoint.physical, into: &point) }
            catch { throw .runtime(error) }
            guard point.count == n, point.allSatisfy({ $0.isFinite }), equations.descriptor == descriptor else { throw .invalidEvaluation }
            var references = [Double](repeating: .nan, count: n)
            for i in 0..<n {
                guard descriptor.dimensions[i] == policy.scales[i].dimension else { throw .invalidInput }
                references[i] = policy.scales[i].absoluteSI + policy.scales[i].relative*abs(point[i])
                guard references[i].isFinite, references[i] > 0 else { throw .invalidInput }
            }
            start = point; scales = references
        } catch {
            let unavailable: Bool
            if case .runtime(let failure) = error { unavailable = failure.failedSupplierWorkUnavailable } else { unavailable = false }
            throw ImplicitIntegrationFailure(cause: error, lastAccepted: expected, work: initialWork, failedSupplierWorkUnavailable: unavailable)
        }
        let preparedWork = initialWork
        capture.update { $0.work = preparedWork }
        do throws(RuntimeFailure) {
            let outcome = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                guard session.snapshot() == expected else { throw RuntimeFailure(.invalidOwnerAccess, message: "Accepted state changed before implicit trial admission.") }
                return try Self.execute(equations: equations, descriptor: descriptor, expected: expected, start: start, scales: scales,
                    time: time, policy: policy, retained: retained, entries: entries,
                    preparedWork: preparedWork, trial: &trial, control: control, capture: capture)
            }
            guard outcome.decision == .accept, let endpoint = capture.read().endpoint,
                  outcome.accepted.checkpoint.physical.time == time else {
                throw RuntimeFailure(.invalidState, message: "Implicit step did not publish its admitted endpoint.")
            }
            return ImplicitEulerStepResult(accepted: outcome.accepted, endpoint: endpoint)
        } catch {
            let state = capture.read()
            throw ImplicitIntegrationFailure(cause: state.cause ?? .runtime(error), lastAccepted: error.lastAccepted ?? session.snapshot(),
                work: state.work, failedSupplierWorkUnavailable: state.unavailable || error.failedSupplierWorkUnavailable)
        }
    }

    private static func execute(equations: any ImplicitODEEquations, descriptor: ODEDescriptor,
        expected: RuntimeAcceptedState, start: [Double], scales: [Double], time: Double,
        policy: ImplicitEulerPolicy, retained: Int, entries: Int, preparedWork: NumericalWork,
        trial: inout RuntimeTrial, control: RuntimeStepControl, capture: ImplicitAttemptCapture) throws(RuntimeFailure) -> RuntimeTrialDecision {
        var work = preparedWork
        defer { capture.update { $0.work = work } }
        do throws(ImplicitMethodCause) {
            do throws(RuntimeFailure) { try control.beginWorkBlock(units: 1) }
            catch { throw .runtime(error) }
            guard trial.timeSeconds == expected.checkpoint.physical.time, equations.descriptor == descriptor,
                  equations.implicitDomain == .smoothEuclidean else { throw .invalidOwnerAccess }
            var observed = [Double](repeating: .nan, count: start.count)
            do throws(RuntimeFailure) { try equations.read(trial, into: &observed) }
            catch { throw .runtime(error) }
            guard observed == start else { throw .invalidOwnerAccess }
            try supplier(work: &work, capture: capture) { ledger throws(RuntimeFailure) in
                try equations.prepare(trial: &trial, work: &ledger, control: control)
            }
            for i in observed.indices { observed[i] = .nan }
            do throws(RuntimeFailure) { try control.beginWorkBlock(units: 1); try equations.read(trial, into: &observed) }
            catch { throw .runtime(error) }
            guard observed == start, trial.timeSeconds == expected.checkpoint.physical.time,
                  equations.descriptor == descriptor, equations.implicitDomain == .smoothEuclidean else { throw .invalidEvaluation }
            let solverPolicy: NonlinearPolicy<Double>
            do throws(NumericalError) { solverPolicy = try ImplicitBudgetComposition.policy(policy.nonlinear, budget: work.remainingBudget(reservedStorage: retained)) }
            catch { throw .numerical(error) }
            let adapter = ImplicitEulerResidual<Double>(equations: equations, descriptor: descriptor, start: start, scales: scales,
                time: time, step: time-expected.checkpoint.physical.time, control: control, capture: capture,
                workspace: ImplicitEquationWorkspacePool(count: start.count, entries: entries))
            let solved: NonlinearSolution<Double>
            do throws(NonlinearFailure<Double>) { solved = try ReferenceNonlinearSolver<Double>().solve(adapter, initialPoint: start, policy: solverPolicy) }
            catch {
                capture.update { $0.unavailable = $0.unavailable || error.failedSupplierWorkUnavailable }
                do throws(NumericalError) { try work.absorb(error.work, reservedStorage: retained) }
                catch { throw .numerical(error) }
                throw .nonlinear(error)
            }
            do throws(NumericalError) { try work.absorb(solved.diagnostics.work, reservedStorage: retained) }
            catch { throw .numerical(error) }
            var derivative = [Double](repeating: .nan, count: start.count)
            try supplier(work: &work, capture: capture) { ledger throws(RuntimeFailure) in
                try control.beginWorkBlock(units: 1)
                try equations.derivative(time: time, point: solved.values, into: &derivative, work: &ledger, control: control)
                try control.beginWorkBlock(units: 1)
            }
            guard solved.values.count == start.count, solved.values.allSatisfy({ $0.isFinite }), derivative.count == start.count,
                  derivative.allSatisfy({ $0.isFinite }), equations.descriptor == descriptor,
                  equations.implicitDomain == .smoothEuclidean else { throw .invalidEvaluation }
            let evidence: ResidualEvidence<Double>
            do throws(NumericalError) {
                try work.chargeOperations(try NumericalWork.product(8,start.count))
                var norm = 0.0
                for i in start.indices {
                    let residual = (solved.values[i]-start[i]-(time-expected.checkpoint.physical.time)*derivative[i])/scales[i]
                    guard residual.isFinite else { throw .nonFiniteResult }
                    norm = max(norm,abs(residual))
                }
                evidence = try ResidualEvidence(infinityNorm: norm, referenceScale: policy.nonlinear.referenceScale,
                    threshold: solved.originalResidual.threshold)
                try evidence.requireAccepted()
            } catch { throw .numerical(error) }
            do throws(RuntimeFailure) {
                try control.beginWorkBlock(units: 1)
                try equations.write(point: solved.values, derivative: derivative, time: time, trial: &trial)
                try control.beginWorkBlock(units: 1)
                for i in observed.indices { observed[i] = .nan }
                try equations.read(trial, into: &observed)
            } catch { throw .runtime(error) }
            guard observed == solved.values, trial.timeSeconds == time, equations.descriptor == descriptor,
                  equations.implicitDomain == .smoothEuclidean else { throw .invalidEvaluation }
            do throws(RuntimeFailure) { try control.beginWorkBlock(units: 1) }
            catch { throw .runtime(error) }
            capture.update { $0.endpoint = ImplicitEulerEndpoint(time: time, point: solved.values, derivative: derivative,
                originalResidual: evidence, nonlinearDiagnostics: solved.diagnostics, work: work) }
            return .accept
        } catch {
            capture.update { state in
                if case nil = state.cause { state.cause = error }
                if case .runtime(let failure) = error { state.unavailable = state.unavailable || failure.failedSupplierWorkUnavailable }
            }
            if case .runtime(let failure) = error { throw failure }
            let code: RuntimeFailureCode
            if case .numerical(.cancelled) = error { code = .cancelled }
            else if case .nonlinear(let failure) = error, failure.termination == .cancelled { code = .cancelled }
            else { code = .invalidState }
            throw RuntimeFailure(code, message: "Implicit step failed; typed cause is retained in the integrator failure.",
                failedSupplierWorkUnavailable: capture.read().unavailable)
        }
    }

    private static func supplier(work: inout NumericalWork, capture: ImplicitAttemptCapture,
        operation: (inout NumericalWork) throws(RuntimeFailure) -> Void) throws(ImplicitMethodCause) {
        let previous = work
        var failure: RuntimeFailure?
        do throws(RuntimeFailure) { try operation(&work) } catch { failure = error }
        guard ImplicitBudgetComposition.preservingLedger(previous,work) else {
            work = previous; capture.update { $0.unavailable = true }
            throw .invalidOwnerAccess
        }
        if let failure { throw .runtime(failure) }
    }
}
