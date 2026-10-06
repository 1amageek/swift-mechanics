/// Dense, bounded-work two-phase simplex with original-data terminal certificates.
public struct TwoPhaseLinearProgramSolver: GeneralLinearProgramSolving, Sendable {
    public init() {}

    public func solve(_ problem: GeneralLinearProgram, policy: LinearProgramPolicy,
                      work: inout NumericalWork) throws(LinearProgramFailure) -> LinearProgramResult {
        var phase = LinearProgramPhase.admission
        var pivots = 0
        do {
            let rows = try LinearOriginalRows.admit(problem, policy: policy, work: &work)
            return try execute(problem, rows: rows, policy: policy, phase: &phase, pivots: &pivots, work: &work)
        } catch {
            throw LinearProgramFailure(cause: error, phase: phase, pivots: pivots, work: work, problem: problem)
        }
    }

    private func execute(_ problem: GeneralLinearProgram, rows: LinearOriginalRows, policy: LinearProgramPolicy,
                         phase: inout LinearProgramPhase, pivots: inout Int,
                         work: inout NumericalWork) throws(LinearProgramCause) -> LinearProgramResult {
        var local = try LinearSimplexTableau(rows: rows, policy: policy, work: &work)
        // Retain failure counters without a second COW owner of any mutable array.
        defer { pivots = local.pivots }
        phase = .phaseOne
        let phaseOneRay = try local.optimize(limit: local.columnCount, policy: policy, work: &work)
        guard phaseOneRay == nil else { throw LinearProgramCause.numericalAmbiguity }
        let phaseOneObjective = try local.objective(policy: policy, work: &work)
        guard phaseOneObjective >= 0 else { throw LinearProgramCause.numericalAmbiguity }
        let phaseOneThreshold = try LinearProgramArithmetic.threshold(policy.phaseOneTolerance, scale: phaseOneObjective)
        let status: LinearProgramStatus
        if phaseOneObjective > phaseOneThreshold {
            phase = .originalCertification
            let weights = try local.originalMultipliers(policy: policy, work: &work)
            status = .infeasible(try LinearOriginalCertificate.infeasible(weights: weights, rows: rows, problem: problem, policy: policy, work: &work))
        } else {
            phase = .artificialRemoval
            try local.removeArtificials(policy: policy, work: &work)
            try local.installCost(problem.linearCost, policy: policy, work: &work)
            phase = .phaseTwo
            let entering = try local.optimize(limit: local.artificialStart, policy: policy, work: &work)
            phase = .originalCertification
            let point = try local.originalPoint(policy: policy, work: &work)
            if let entering {
                let direction = try local.originalRay(entering: entering, policy: policy, work: &work)
                status = .unbounded(try LinearOriginalCertificate.unbounded(point: point, direction: direction, rows: rows, problem: problem, policy: policy, work: &work))
            } else {
                let weights = try local.originalMultipliers(policy: policy, work: &work)
                status = .optimal(try LinearOriginalCertificate.optimal(point: point, weights: weights, rows: rows, problem: problem, policy: policy, work: &work))
            }
        }
        try LinearProgramArithmetic.checkpoint(policy)
        return LinearProgramResult(problem: problem, status: status, pivots: local.pivots, numericalWork: work)
    }
}
