import MechanicsComplementarity
import MechanicsNumerics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SolveTests {
    @Test func frictionlessLCPAndNonDiagonallyDominantSPDHaveAnalyticOptima() throws {
        let solver: any ComplementaritySolving = ProjectedComplementaritySolver()
        let policy = try ComplementarityFixtures.policy()
        let solution = try solver.solve(ComplementarityFixtures.problem(), policy: policy, warmStart: nil)
        #expect(ComplementarityFixtures.close(solution.values[0], 0.5))
        #expect(solution.values[1] == 0)
        #expect(ComplementarityFixtures.close(solution.dualValues[0], 0, absolute: 1e-9))
        #expect(ComplementarityFixtures.close(solution.dualValues[1], 0.5))
        #expect(ComplementarityFixtures.close(solution.objective, -0.25))
        #expect(solution.diagnostics.originalResidual.isAccepted)
        #expect(solution.diagnostics.termination == .accepted)
        #expect(solution.diagnostics.work.operations <= policy.budget.arithmeticOperations)
        #expect(solution.diagnostics.work.peakScalarStorage <= policy.budget.scalarStorage)
        #expect(solution.diagnostics.work.iterations <= policy.budget.iterations)
        for i in 0..<2 { #expect(abs(solution.values[i] * solution.dualValues[i]) <= 1.1e-9) }
        // A=[1,2;2,5] is SPD (leading minors 1,1) but not row diagonally dominant.
        let generalSPD = try ComplementarityFixtures.problem(values: [1, 2, 2, 5], b: [-5, -12])
        let other = try solver.solve(generalSPD, policy: policy, warmStart: nil)
        #expect(ComplementarityFixtures.close(other.values[0], 1))
        #expect(ComplementarityFixtures.close(other.values[1], 2))
        #expect(abs(other.values[0] + 2 * other.values[1] - 5) < 1.1e-9)
        #expect(abs(2 * other.values[0] + 5 * other.values[1] - 12) < 1.1e-9)
    }

    @Test func associatedFrictionConeAndZeroFrictionRayHaveIndependentBalances() throws {
        let solver: any ComplementaritySolving = ProjectedComplementaritySolver()
        let problem = try ComplementarityFixtures.problem(values: [2, 0, 0, 0, 3, 0, 0, 0, 4],
            b: [-3.5, -4, 0], cone: .associatedFrictionCones(coefficients: [0.5]))
        let solution = try solver.solve(problem, policy: ComplementarityFixtures.policy(), warmStart: nil)
        #expect(ComplementarityFixtures.close(solution.values[0], 2))
        #expect(ComplementarityFixtures.close(solution.values[1], 1))
        #expect(solution.values[2] == 0)
        #expect(ComplementarityFixtures.close(solution.dualValues[0], 0.5))
        #expect(ComplementarityFixtures.close(solution.dualValues[1], -1))
        #expect(ComplementarityFixtures.close(solution.objective, -5.5))
        let n = solution.values[0], t = solution.values[1], wn = solution.dualValues[0], wt = solution.dualValues[1]
        #expect(abs(t) <= 0.5 * n + 1.1e-9)
        #expect(wn >= 0.5 * abs(wt) - 1.1e-9)
        #expect(abs(n * wn + t * wt) <= 1.1e-9)
        #expect(abs(wn - (2 * n - 3.5)) < 1e-12)
        #expect(abs(wt - (3 * t - 4)) < 1e-12)
        #expect(solution.diagnostics.originalResidual.isAccepted)
        let ray = try ComplementarityFixtures.problem(values: [2, 0, 0, 0, 3, 0, 0, 0, 4], b: [-2, -100, -50],
            cone: .associatedFrictionCones(coefficients: [0]))
        let raySolution = try solver.solve(ray, policy: ComplementarityFixtures.policy(), warmStart: nil)
        #expect(ComplementarityFixtures.close(raySolution.values[0], 1))
        #expect(raySolution.values[1] == 0 && raySolution.values[2] == 0)
        #expect(raySolution.diagnostics.originalResidual.isAccepted)
    }

    @Test func coldWarmAndValueRestartAgreeWithoutResidualBypass() throws {
        let solver: any ComplementaritySolving = ProjectedComplementaritySolver()
        let problem = try ComplementarityFixtures.problem()
        let policy = try ComplementarityFixtures.policy()
        let cold = try solver.solve(problem, policy: policy, warmStart: nil)
        let warm = try solver.solve(problem, policy: policy, warmStart: cold.cache)
        let restored = try ComplementarityCache(problem: cold.cache.problem, iterate: cold.cache.iterate,
            inverseRowBound: cold.cache.inverseRowBound)
        let replay = try solver.solve(problem, policy: policy, warmStart: restored)
        #expect(warm.values == cold.values)
        #expect(replay.values == warm.values)
        #expect(warm.diagnostics.originalResidual.isAccepted && replay.diagnostics.originalResidual.isAccepted)
        #expect(warm.diagnostics.projectedIterations == 0)
        #expect(warm.diagnostics.work.iterations >= 2) // Mandatory Cholesky admission still runs.
        #expect(warm.diagnostics.usedWarmStart)
        let rejectedGuess = try ComplementarityCache(problem: problem, iterate: [0, 0], inverseRowBound: cold.cache.inverseRowBound)
        do {
            _ = try solver.solve(problem, policy: ComplementarityFixtures.policy(maximumIterations: 0), warmStart: rejectedGuess)
            Issue.record("A warm guess cannot bypass original residual acceptance")
        } catch {
            guard case ComplementarityError.numerical(.nonConvergence(let iterations, let residual)) = error else {
                Issue.record("Expected nonconvergence, received \(error)"); return
            }
            #expect(iterations == 0 && residual > 0)
        }
        let forged = try ComplementarityCache(problem: problem, iterate: cold.values, inverseRowBound: 1e-200)
        #expect(throws: ComplementarityError.invalidRestart) { try solver.solve(problem, policy: policy, warmStart: forged) }
        #expect(throws: ComplementarityError.invalidRestart) { try ComplementarityCache(problem: problem, iterate: [.nan, 0], inverseRowBound: 1) }
        #expect(throws: ComplementarityError.invalidRestart) { try ComplementarityCache(problem: problem, iterate: [0], inverseRowBound: 1) }
        #expect(cold.cache.iterate == cold.values)
    }

    @Test func staleSemanticAndNumericSnapshotsAreRejected() throws {
        let solver: any ComplementaritySolving = ProjectedComplementaritySolver()
        let original = try ComplementarityFixtures.problem()
        let policy = try ComplementarityFixtures.policy()
        let cache = try solver.solve(original, policy: policy, warmStart: nil).cache
        let changed = try [
            ComplementarityFixtures.problem(revision: 2),
            ComplementarityFixtures.problem(coordinates: [1, 0]),
            ComplementarityFixtures.problem(frameRevision: 2),
            ComplementarityFixtures.problem(lawRevision: 2),
            ComplementarityFixtures.problem(values: [3, -1, -1, 2]),
            ComplementarityFixtures.problem(b: [-2, 1]),
        ]
        for problem in changed {
            #expect(throws: ComplementarityError.staleCache) { try solver.solve(problem, policy: policy, warmStart: cache) }
        }
        let cone = try ComplementarityFixtures.problem(values: [2, 0, 0, 0, 3, 0, 0, 0, 4], b: [-3.5, -4, 0], cone: .associatedFrictionCones(coefficients: [0.5]))
        let coneCache = try solver.solve(cone, policy: policy, warmStart: nil).cache
        let changedLaw = try ComplementarityFixtures.problem(values: [2, 0, 0, 0, 3, 0, 0, 0, 4], b: [-3.5, -4, 0], cone: .associatedFrictionCones(coefficients: [0.6]))
        #expect(throws: ComplementarityError.staleCache) { try solver.solve(changedLaw, policy: policy, warmStart: coneCache) }
        #expect(cache.problem.identity == original.identity)
    }

    @Test func invalidDomainsAndPrematureAcceptanceAreRejected() throws {
        let solver: any ComplementaritySolving = ProjectedComplementaritySolver()
        let policy = try ComplementarityFixtures.policy()
        #expect(throws: ComplementarityError.unsupportedLaw) { try ComplementarityFixtures.problem(cone: .nonAssociatedCoulomb(dimension: 2)) }
        #expect(throws: ComplementarityError.invalidIdentity) { try ComplementarityFixtures.problem(coordinates: [1, 1]) }
        #expect(throws: ComplementarityError.numerical(.nonFiniteInput)) { try ComplementarityFixtures.problem(b: [.nan, 1]) }
        let nonsymmetric = try ComplementarityFixtures.problem(values: [1, 2, 0, 1], b: [0, 0])
        #expect(throws: ComplementarityError.numerical(.nonsymmetric)) { try solver.solve(nonsymmetric, policy: policy, warmStart: nil) }
        let indefinite = try ComplementarityFixtures.problem(values: [-1, 0, 0, -1], b: [0, 0])
        #expect(throws: ComplementarityError.numerical(.nonPositiveDefinite(pivot: 0))) { try solver.solve(indefinite, policy: policy, warmStart: nil) }
        #expect(throws: ComplementarityError.numerical(.unsupportedCapability)) { try solver.solve(ComplementarityFixtures.problem(), policy: ComplementarityFixtures.policy(precision: .float32), warmStart: nil) }
        #expect(throws: ComplementarityError.numerical(.unsupportedCapability)) { try solver.solve(ComplementarityFixtures.problem(), policy: ComplementarityFixtures.policy(backend: .acceleratedDevice), warmStart: nil) }
        let extreme = try ComplementarityFixtures.problem(values: [1, 0, 0, 0, 1, 0, 0, 0, 1],
            b: [-Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude], cone: .associatedFrictionCones(coefficients: [0.5]))
        #expect(throws: ComplementarityError.numerical(.nonFiniteResult)) { try solver.solve(extreme, policy: policy, warmStart: nil) }
    }

    @Test func iterationWorkStorageAndCancellationRemainFailures() async throws {
        let solver: any ComplementaritySolving = ProjectedComplementaritySolver()
        let problem = try ComplementarityFixtures.problem()
        #expect(throws: ComplementarityError.numerical(.resourceLimit(resource: .scalarStorage, limit: 1))) {
            try solver.solve(problem, policy: ComplementarityFixtures.policy(storage: 1), warmStart: nil)
        }
        #expect(throws: ComplementarityError.numerical(.resourceLimit(resource: .arithmeticOperations, limit: 0))) {
            try solver.solve(problem, policy: ComplementarityFixtures.policy(operations: 0), warmStart: nil)
        }
        #expect(throws: ComplementarityError.numerical(.resourceLimit(resource: .iterations, limit: 3))) {
            try solver.solve(problem, policy: ComplementarityFixtures.policy(iterations: 3), warmStart: nil)
        }
        do {
            _ = try solver.solve(problem, policy: ComplementarityFixtures.policy(maximumIterations: 1), warmStart: nil)
            Issue.record("Rejected residual must not become success at iteration limit")
        } catch {
            guard case ComplementarityError.numerical(.nonConvergence(let iterations, let residual)) = error else {
                Issue.record("Expected explicit nonconvergence, received \(error)"); return
            }
            #expect(iterations == 1 && residual > 1e-9)
        }
        let policy = try ComplementarityFixtures.policy()
        let cancelled = Task {
            while !Task.isCancelled { await Task.yield() }
            return try solver.solve(problem, policy: policy, warmStart: nil)
        }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            Issue.record("Cancelled solve must fail")
        } catch {
            #expect(error as? ComplementarityError == .numerical(.cancelled))
        }
    }
}
