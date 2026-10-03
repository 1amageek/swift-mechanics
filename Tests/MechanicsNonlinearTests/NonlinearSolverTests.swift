import Testing
import MechanicsNumerics
import MechanicsNonlinear

@Suite struct NonlinearSolverTests {
    private func policy(strategy: NonlinearStrategy<Double> = .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4, minimumFraction: 1e-8),
                        storage: Int = 10000, operations: Int = 1000000, iterations: Int = 500, fill: Int = 100,
                        condition: Bool = false, minimumDirection: Double = 0) throws -> NonlinearPolicy<Double> {
        try NonlinearPolicy(strategy: strategy, capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            tolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-14),
            referenceScale: 1, minimumDirectionNorm: minimumDirection, derivativeProbeDistance: 1e-6,
            derivativeAbsoluteTolerance: 1e-6, derivativeRelativeTolerance: 1e-5, maximumFactorEntries: fill,
            estimateCondition: condition, budget: NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations))
    }
    private func failure(_ equations: any NonlinearEquations<Double>, point: [Double] = [0.1], policy: NonlinearPolicy<Double>) -> NonlinearFailure<Double>? {
        do {
            _ = try ReferenceNonlinearSolver<Double>().solve(equations, initialPoint: point, policy: policy)
            Issue.record("Expected a typed nonlinear failure")
            return nil
        } catch { return error }
    }

    @Test func difficultStartUsesRealNewtonLineSearchAndTrustRegion() throws {
        let problem = CubicEquation<Double>()
        let initial = [0.1]
        let solver: any NonlinearSolving<Double> = ReferenceNonlinearSolver()
        let strategies: [NonlinearStrategy<Double>] = [.newton,
            .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4, minimumFraction: 1e-8),
            .trustRegion(initialRadius: 10, minimumRadius: 1e-8, maximumRadius: 20, acceptanceRatio: 0.1,
                shrinkRatio: 0.25, growRatio: 0.75, contraction: 0.5, expansion: 2)]
        for strategy in strategies {
            let solved = try solver.solve(problem, initialPoint: initial, policy: policy(strategy: strategy))
            #expect(abs(solved.values[0]-1) < 1e-9)
            #expect(abs(solved.values[0]*solved.values[0]*solved.values[0]-1) < 2e-10)
            #expect(solved.internalResidual.isAccepted && solved.originalResidual.isAccepted)
            #expect(solved.diagnostics.originalEvaluations == 1)
            #expect(solved.diagnostics.tangentRank == 1)
            #expect(solved.diagnostics.acceptedSteps > 0)
            if case .newton = strategy {} else { #expect(solved.diagnostics.rejectedSteps > 0) }
            #expect(solved.diagnostics.activeSetChanges == .notDefinedByEquationProvider)
            #expect(solved.diagnostics.feasibility == .notDefinedByEquationProvider)
        }
        #expect(initial == [0.1])
    }

    @Test func domainRejectedTrialsRetainCallerPointAndNewtonFails() throws {
        let problem = CubicEquation<Double>(upperBound: 2)
        let initial = [0.1]
        let solved = try ReferenceNonlinearSolver<Double>().solve(problem, initialPoint: initial, policy: policy())
        #expect(abs(solved.values[0]-1) < 1e-9)
        #expect(solved.diagnostics.rejectedSteps > 0)
        let failed = try #require(failure(problem, point: initial, policy: policy(strategy: .newton)))
        #expect(failed.phase == .trial)
        #expect(failed.cause == .equation(.outsideDomain))
        #expect(failed.lastIterate == initial)
        #expect(initial == [0.1])
    }

    @Test func singularTangentBadDerivativeAndStalledStepFail() throws {
        let singular = try #require(failure(CubicEquation<Double>(), point: [0], policy: policy()))
        #expect(singular.phase == .linearSolve)
        #expect(singular.cause == .numerical(.singular(rank: 0, pivot: 0)))
        #expect(singular.failedSupplierWorkUnavailable)
        let inaccurate = try #require(failure(CubicEquation<Double>(derivativeMultiplier: 2), policy: policy()))
        #expect(inaccurate.phase == .derivativeProbe)
        if case .invalidDerivative(let error, let threshold) = inaccurate.cause { #expect(error > threshold) }
        else { Issue.record("Wrong derivative must fail its directional check") }
        let malformed = try #require(failure(InvalidDerivativeEquation(), policy: policy()))
        #expect(malformed.phase == .jacobian)
        #expect(malformed.cause == .invalidEvaluation)
        let stalled = try #require(failure(CubicEquation<Double>(), policy: policy(minimumDirection: 100)))
        #expect(stalled.cause == .noAcceptableStep)
    }

    @Test func prematureInternalConvergenceCannotBypassOriginalEquation() throws {
        let dishonest = try #require(failure(CubicEquation<Double>(dishonestInternalResidual: true), policy: policy()))
        #expect(dishonest.phase == .originalAcceptance)
        if case .originalResidualDisagreement(let internalNorm, let originalNorm, let threshold) = dishonest.cause {
            #expect(internalNorm == 0)
            #expect(originalNorm > 0.99 && originalNorm > threshold)
        } else { Issue.record("Original equations must reject false internal convergence") }
        #expect(dishonest.termination == .nonConvergence)
    }

    @Test func actualInverseColumnsDiagnoseConditionAndUnavailableMetrics() throws {
        let solved = try ReferenceNonlinearSolver<Double>().solve(IllConditionedEquation(), initialPoint: [0,0], policy: policy(strategy: .newton, condition: true))
        #expect(abs(solved.values[0]-1) < 1e-12 && abs(solved.values[1]-2) < 1e-12)
        #expect(solved.diagnostics.tangentRank == 2)
        #expect(solved.diagnostics.tangentPoint == [0,0])
        if case .available(let estimate) = solved.diagnostics.conditionOneNorm { #expect(abs(estimate-1e8) < 1) }
        else { Issue.record("Requested condition estimate must be available") }
        #expect(solved.diagnostics.constraintRank == .notDefinedByEquationProvider)
        #expect(solved.diagnostics.optimality == .notDefinedByEquationProvider)
        let alreadySolved = try ReferenceNonlinearSolver<Double>().solve(IllConditionedEquation(), initialPoint: [1,2], policy: policy())
        if case .unavailable(let reason) = alreadySolved.diagnostics.conditionOneNorm { #expect(reason == .noTangentEvaluated) }
        else { Issue.record("No tangent must not invent a condition estimate") }
    }

    @Test func everyBudgetFailureCarriesLastResidualAndPhase() throws {
        let problem = CubicEquation<Double>()
        let domainWork = try #require(failure(CubicEquation<Double>(upperBound: 2), policy: policy(operations: 0)))
        #expect(domainWork.phase == .initialResidual)
        #expect(domainWork.cause == .numerical(.resourceLimit(resource: .arithmeticOperations, limit: 0)))
        #expect(domainWork.lastResidual == nil)
        let memory = try #require(failure(problem, policy: policy(storage: 7)))
        #expect(memory.phase == .workspace)
        #expect(memory.cause == .numerical(.resourceLimit(resource: .scalarStorage, limit: 7)))
        #expect(memory.lastResidual == 0.999)
        let arithmetic = try #require(failure(problem, policy: policy(operations: 6)))
        #expect(arithmetic.phase == .jacobian)
        #expect(arithmetic.cause == .numerical(.resourceLimit(resource: .arithmeticOperations, limit: 6)))
        #expect(arithmetic.lastResidual == 0.999)
        let iteration = try #require(failure(problem, policy: policy(iterations: 0)))
        #expect(iteration.phase == .iteration)
        #expect(iteration.cause == .numerical(.resourceLimit(resource: .iterations, limit: 0)))
        #expect(iteration.lastResidual == 0.999)
        let nested = try #require(failure(problem, policy: policy(iterations: 1)))
        #expect(nested.phase == .linearSolve && nested.failedSupplierWorkUnavailable)
        #expect(nested.lastResidual == 0.999)
        let fill = try #require(failure(problem, policy: policy(fill: 0)))
        #expect(fill.phase == .linearSolve)
        #expect(fill.cause == .denseFillLimit(required: 1, limit: 0))
        #expect(fill.lastResidual == 0.999)
        #expect(fill.lastIterate == [0.1])
    }

    @available(macOS 15.0, *)
    @Test func mutableMetadataCannotChangeCapturedLayout() throws {
        let changedLayout = try #require(failure(MutatingLayoutEquation(), point: [0], policy: policy()))
        #expect(changedLayout.phase == .initialResidual)
        #expect(changedLayout.cause == .equationMetadataChanged)
        #expect(changedLayout.lastIterate == [0])
    }

    @Test func incompleteOutputsAndDerivativeDomainBoundaryFail() throws {
        let incomplete = try #require(failure(IncompleteEvaluationEquation(incompleteOriginal: false), point: [0,0], policy: policy()))
        #expect(incomplete.phase == .initialResidual && incomplete.cause == .invalidEvaluation)
        #expect(incomplete.lastResidual == nil)
        let incompleteOriginal = try #require(failure(IncompleteEvaluationEquation(incompleteOriginal: true), point: [1,1], policy: policy()))
        #expect(incompleteOriginal.phase == .originalAcceptance && incompleteOriginal.cause == .invalidEvaluation)
        let boundary = try #require(failure(CubicEquation<Double>(upperBound: 0.1), policy: policy()))
        #expect(boundary.phase == .derivativeProbe)
        #expect(boundary.cause == .equation(.outsideDomain))
        #expect(boundary.lastIterate == [0.1])
        let rejected = try #require(failure(CubicEquation<Double>(), policy: policy(strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4, minimumFraction: 1))))
        #expect(rejected.phase == .trial && rejected.cause == .noAcceptableStep)
        #expect(rejected.lastIterate == [0.1])
    }

    @Test func cancellationIsTypedAndBounded() async throws {
        let selected = try policy()
        let gate = AsyncStream<Void>.makeStream()
        let task = Task { () -> NonlinearFailure<Double>? in
            for await _ in gate.stream { break }
            do { _ = try ReferenceNonlinearSolver<Double>().solve(CubicEquation<Double>(), initialPoint: [0.1], policy: selected); return nil }
            catch let error as NonlinearFailure<Double> { return error }
            catch { Issue.record("Unexpected untyped cancellation failure"); return nil }
        }
        task.cancel(); gate.continuation.finish()
        let failed = try #require(await task.value)
        #expect(failed.cause == .numerical(.cancelled))
        #expect(failed.phase == .validation)
        #expect(failed.lastIterate == [0.1])
        #expect(failed.lastResidual == nil)
    }

    @Test func cancellationDuringOriginalRecomputationCannotReturnSuccess() async throws {
        let selected = try policy()
        let task = Task { () -> NonlinearFailure<Double>? in
            do {
                _ = try ReferenceNonlinearSolver<Double>().solve(CubicEquation<Double>(cancelOnOriginal: true), initialPoint: [1], policy: selected)
                return nil
            } catch let error as NonlinearFailure<Double> { return error }
            catch { Issue.record("Unexpected untyped original-acceptance failure"); return nil }
        }
        let failed = try #require(await task.value)
        #expect(failed.phase == .originalAcceptance)
        #expect(failed.cause == .numerical(.cancelled))
        #expect(failed.lastIterate == [1])
    }

    @Test func selectedFloat32ExecutesAndUnsupportedPrecisionRejects() throws {
        let selected = try NonlinearPolicy<Float>(strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4, minimumFraction: 1e-6),
            capability: LinearCapability(precision: .float32, backend: .referenceCPU, algorithm: .partialPivotLU),
            tolerance: LinearTolerance(absoluteResidual: 1e-5, relativeResidual: 1e-5, pivotThreshold: 1e-7), referenceScale: 1,
            minimumDirectionNorm: 0, derivativeProbeDistance: 1e-3, derivativeAbsoluteTolerance: 1e-2, derivativeRelativeTolerance: 1e-3,
            maximumFactorEntries: 1, estimateCondition: false,
            budget: NumericalBudget(scalarStorage: 1000, arithmeticOperations: 100000, iterations: 200))
        let solved = try ReferenceNonlinearSolver<Float>().solve(CubicEquation<Float>(), initialPoint: [0.1], policy: selected)
        #expect(abs(solved.values[0]-1) < 1e-5)
        #expect(solved.originalResidual.isAccepted)
        let unsupported = try NonlinearPolicy<Float>(strategy: .newton,
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            tolerance: selected.tolerance, referenceScale: 1, minimumDirectionNorm: 0, derivativeProbeDistance: 1e-3,
            derivativeAbsoluteTolerance: 1e-2, derivativeRelativeTolerance: 1e-3, maximumFactorEntries: 1, estimateCondition: false, budget: selected.budget)
        do {
            _ = try ReferenceNonlinearSolver<Float>().solve(CubicEquation<Float>(), initialPoint: [0.1], policy: unsupported)
            Issue.record("Precision mismatch must be rejected")
        } catch { #expect(error.cause == .numerical(.unsupportedCapability)) }
    }
}
