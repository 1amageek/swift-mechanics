public struct BoundedPoseIKSolver: PoseIKSolving, Sendable {
    public init() {}

    @inline(never)
    public func solve(_ problem: PoseIKProblem, policy: PoseIKPolicy) throws(PoseIKFailure) -> PoseIKResult {
        var work = NumericalWork(budget: policy.budget)
        var last: [Double]? = problem.initialPositions
        var evidence: PoseIKEvidence?
        var unavailable: PoseIKError?
        do throws(PoseIKError) {
            let a = try PoseIKAdmission(problem, policy: policy, work: &work)
            let n = problem.layout.scales.count, d = a.solverCount
            var initial = [Double](repeating: 0, count: d)
            try PoseIKArithmetic.charge(2*n, &work)
            for i in 0..<n { initial[i] = problem.initialPositions[i]/problem.layout.scales[i] }
            // Prove original input validity and retain initial witnesses before nonlinear work.
            let initialSample = try PoseIKTaskEvaluator(admission: a).evaluate(initial, original: true, work: &work)
            evidence = try PoseIKOriginalAcceptance.evidence(initialSample, admission: a, work: &work)
            let numerical = try nestedPolicy(policy.nonlinear, reserved: a.retainedStorage, work: work)
            let solution: NonlinearSolution<Double>
            do {
                solution = try ReferenceNonlinearSolver<Double>().solve(PoseIKEquations(admission: a), initialPoint: initial, policy: numerical)
            } catch {
                do { try work.absorb(error.work, reservedStorage: a.retainedStorage) }
                catch { throw .numerical(error) }
                evidence = nil
                last = nil
                if error.lastIterate.count == d {
                    do throws(PoseIKError) {
                        try PoseIKArithmetic.charge(2*n, &work)
                        var positions = [Double](repeating: 0, count: n)
                        for i in 0..<n { positions[i] = try PoseIKArithmetic.finite(error.lastIterate[i]*problem.layout.scales[i]) }
                        last = positions
                    } catch { unavailable = error }
                }
                if canObserve(error.cause), error.lastIterate.count == d {
                    do throws(PoseIKError) {
                        let original = try PoseIKTaskEvaluator(admission: a).evaluate(error.lastIterate, original: true, work: &work)
                        evidence = try PoseIKOriginalAcceptance.evidence(original, admission: a, work: &work)
                    } catch { unavailable = error }
                } else if unavailable == nil { unavailable = .nonlinear(error) }
                throw .nonlinear(error)
            }
            do { try work.absorb(solution.diagnostics.work, reservedStorage: a.retainedStorage) }
            catch { throw .numerical(error) }
            guard solution.values.count == d, solution.values.allSatisfy({ $0.isFinite }) else { throw .invalidShape }
            evidence = nil; last = nil
            let original = try PoseIKTaskEvaluator(admission: a).evaluate(solution.values, original: true, work: &work)
            last = original.state.q
            evidence = try PoseIKOriginalAcceptance.evidence(original, admission: a, work: &work)
            if let evidence { try PoseIKOriginalAcceptance.reject(evidence, admission: a) }
            let rank = try PoseIKOriginalAcceptance.rank(original, admission: a, work: &work)
            evidence = try PoseIKOriginalAcceptance.evidence(original, admission: a, rank: rank, work: &work)
            guard rank.rank == a.rows.count else { throw .singularRows(rank: rank.rank, rows: a.rows.count) }
            guard let accepted = evidence, accepted.isFeasible else { throw .invalidInput }
            try PoseIKArithmetic.check(policy)
            return PoseIKResult(identity: problem.identity, source: problem, state: original.state,
                initialPositions: problem.initialPositions, referencePositions: problem.referencePositions, branch: problem.branch,
                queryMultipliers: Array(solution.values[n..<d]), original: accepted, nonlinear: solution, work: work)
        } catch {
            throw PoseIKFailure(identity: problem.identity, cause: error, lastPositions: last,
                original: evidence, originalUnavailable: unavailable, work: work)
        }
    }

    private func nestedPolicy(_ supplied: NonlinearPolicy<Double>, reserved: Int,
                              work: NumericalWork) throws(PoseIKError) -> NonlinearPolicy<Double> {
        do {
            let remaining = try work.remainingBudget(reservedStorage: reserved)
            let budget = try NumericalBudget(scalarStorage: min(supplied.budget.scalarStorage,remaining.scalarStorage),
                arithmeticOperations: min(supplied.budget.arithmeticOperations,remaining.arithmeticOperations),
                iterations: min(supplied.budget.iterations,remaining.iterations))
            return try NonlinearPolicy(strategy: supplied.strategy, capability: supplied.capability, tolerance: supplied.tolerance,
                referenceScale: supplied.referenceScale, minimumDirectionNorm: supplied.minimumDirectionNorm,
                derivativeProbeDistance: supplied.derivativeProbeDistance, derivativeAbsoluteTolerance: supplied.derivativeAbsoluteTolerance,
                derivativeRelativeTolerance: supplied.derivativeRelativeTolerance, maximumFactorEntries: supplied.maximumFactorEntries,
                estimateCondition: supplied.estimateCondition, budget: budget)
        } catch { throw .numerical(error) }
    }
    private func canObserve(_ cause: NonlinearCause) -> Bool {
        switch cause {
        case .noAcceptableStep, .originalResidualDisagreement: return true
        case .numerical(.singular): return true
        default: return false
        }
    }
}
