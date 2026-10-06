@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceStructuralImplicitStepper: StructuralImplicitStepping, Sendable {
    public init() {}
    public func step(_ input: StructuralIntegrationState, equations: any StructuralImplicitEquations, to time: Double,
                     policy: StructuralImplicitPolicy) throws(StructuralImplicitFailure) -> StructuralImplicitEndpoint {
        var work = NumericalWork(budget: policy.nonlinear.budget)
        let capture = StructuralAttemptCapture()
        do throws(ImplicitMethodCause) {
            guard !Task.isCancelled else { throw .numerical(.cancelled) }
            guard equations.implicitDomain == .smoothEuclidean, equations.massDomain == .constantMass else { throw .unsupportedDomain }
            let n = input.displacement.count, h = time-input.time, p = policy.parameters
            guard equations.descriptor == input.descriptor, policy.residualScales.count == n,
                  equations.residualDimensions.count == n, time.isFinite, time > input.time,
                  h.isFinite, h > 0, (h*h).isFinite, h*h > 0,
                  ((1-p.alphaF)*p.beta*h*h).isFinite, ((1-p.alphaF)*p.beta*h*h) > 0,
                  time-p.alphaF*h >= input.time, time-p.alphaF*h <= time else { throw .invalidInput }
            for i in 0..<n { guard policy.residualScales[i].dimension == equations.residualDimensions[i] else { throw .invalidInput } }
            let entries: Int, retained: Int, nested: NonlinearPolicy<Double>
            do throws(NumericalError) {
                entries = try NumericalWork.product(n,n)
                retained = try NumericalWork.sum(NumericalWork.product(2,entries), NumericalWork.product(16,n))
                try work.requireStorage(retained)
                try work.chargeOperations(try NumericalWork.product(8,n))
                nested = try ImplicitBudgetComposition.policy(policy.nonlinear, budget: work.remainingBudget(reservedStorage: retained))
            } catch { throw .numerical(error) }
            let adapter = StructuralStepResidual<Double>(equations: equations, input: input, scales: policy.residualScales,
                parameters: p, time: time, step: h, workspace: StructuralWorkspacePool(count: n, entries: entries), capture: capture)
            let solved: NonlinearSolution<Double>
            do throws(NonlinearFailure<Double>) { solved = try ReferenceNonlinearSolver<Double>().solve(adapter, initialPoint: input.acceleration, policy: nested) }
            catch {
                do throws(NumericalError) { try work.absorb(error.work, reservedStorage: retained) }
                catch { throw .numerical(error) }
                if error.failedSupplierWorkUnavailable { capture.fail(.nonlinear(error), unavailable: true) }
                throw .nonlinear(error)
            }
            do throws(NumericalError) { try work.absorb(solved.diagnostics.work, reservedStorage: retained) }
            catch { throw .numerical(error) }
            guard solved.values.count == n, solved.values.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
            // Original residual acceptance was performed by the supplier through the required
            // independent physical-balance witness, including both HHT endpoints.
            guard solved.originalResidual.isAccepted else { throw .invalidEvaluation }
            do throws(NumericalError) { try work.chargeOperations(try NumericalWork.product(24,n)) }
            catch { throw .numerical(error) }
            var displacement = [Double](repeating: .nan, count: n), velocity = [Double](repeating: .nan, count: n)
            for i in 0..<n {
                guard !Task.isCancelled else { throw .numerical(.cancelled) }
                displacement[i] = input.displacement[i]+h*input.velocity[i]+h*h*((0.5-p.beta)*input.acceleration[i]+p.beta*solved.values[i])
                velocity[i] = input.velocity[i]+h*((1-p.gamma)*input.acceleration[i]+p.gamma*solved.values[i])
            }
            guard equations.descriptor == input.descriptor, equations.implicitDomain == .smoothEuclidean,
                  equations.massDomain == .constantMass, equations.residualDimensions.count == n else { throw .invalidEvaluation }
            for i in 0..<n { guard equations.residualDimensions[i] == policy.residualScales[i].dimension else { throw .invalidEvaluation } }
            let state = try StructuralIntegrationState(descriptor: input.descriptor, time: time, displacement: displacement,
                velocity: velocity, acceleration: solved.values)
            guard !Task.isCancelled else { throw .numerical(.cancelled) }
            return StructuralImplicitEndpoint(state: state, parameters: p, originalResidual: solved.originalResidual,
                nonlinearDiagnostics: solved.diagnostics, work: work)
        } catch {
            let state = capture.read()
            var unavailable = state.unavailable
            if case .nonlinear(let failure) = error { unavailable = unavailable || failure.failedSupplierWorkUnavailable }
            if case .runtime(let failure) = error { unavailable = unavailable || failure.failedSupplierWorkUnavailable }
            throw StructuralImplicitFailure(cause: state.cause ?? error, input: input, work: work, failedSupplierWorkUnavailable: unavailable)
        }
    }
}
