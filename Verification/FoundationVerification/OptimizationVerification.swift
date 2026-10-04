import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    static func verifyOptimization() throws {
        try verifyLinearOptimum()
        try verifyQuadraticOptimum()
        try verifyInfeasibilityAndRefusal()
    }

    @inline(never)
    private static func verifyLinearOptimum() throws {
        let p = try ConvexOptimizationProblem(metadata: OptimizationProbeContext.metadata(variables: 2, inequality: true, scaled: true),
            linearCost: [-1, -2], inequalities: OptimizationProbeContext.row([1, 1]), inequalityRightHandSide: [1],
            lowerBounds: [0, 0], upperBounds: [2, 2])
        var workspace = EnumerationWorkspace(), work = try OptimizationProbeContext.work()
        let solver: any OptimizationSolving = CompleteConvexOptimizer()
        let result = try solver.solve(p, policy: OptimizationProbeContext.policy(), workspace: &workspace, work: &work)
        guard let c = result.optimum, let point = result.physicalPoint, let objective = result.physicalObjective else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        try require(result.status == .optimal && result.uniqueness == .notEstablished)
        try require(abs(c.point[0]) < 1e-8 && abs(c.point[1] - 1) < 1e-8 && abs(c.objective + 2) < 1e-8)
        try require(c.point[0] + c.point[1] <= 1 + 1e-8 && c.point[0] >= -1e-8 && c.point[1] >= -1e-8)
        let lambda = c.inequalityMultipliers[0]
        try require(lambda >= 0 && c.lowerMultipliers[0] >= 0 && c.lowerMultipliers[1] >= 0)
        try require(c.upperMultipliers[0] >= 0 && c.upperMultipliers[1] >= 0)
        try require(abs(-1 + lambda - c.lowerMultipliers[0] + c.upperMultipliers[0]) < 1e-8)
        try require(abs(-2 + lambda - c.lowerMultipliers[1] + c.upperMultipliers[1]) < 1e-8)
        try require(abs(lambda * (c.point[0] + c.point[1] - 1)) < 1e-8)
        try require(abs(c.lowerMultipliers[0] * c.point[0]) + abs(c.lowerMultipliers[1] * c.point[1]) < 1e-8)
        try require(abs(point[0]) < 1e-8 && abs(point[1] - 4) < 1e-8 && abs(objective + 6) < 1e-8)
    }

    @inline(never)
    private static func verifyQuadraticOptimum() throws {
        let p = try ConvexOptimizationProblem(metadata: OptimizationProbeContext.metadata(variables: 2, equality: true),
            linearCost: [-3, 0], hessian: DenseMatrix(rows: 2, columns: 2, values: [2, 1, 1, 2]),
            equalities: OptimizationProbeContext.row([1, 1]), equalityRightHandSide: [1], lowerBounds: [0, 0], upperBounds: [2, 2])
        var workspace = EnumerationWorkspace(), work = try OptimizationProbeContext.work()
        let solver: any OptimizationSolving = CompleteConvexOptimizer()
        let result = try solver.solve(p, policy: OptimizationProbeContext.policy(), workspace: &workspace, work: &work)
        guard let c = result.optimum else { throw FoundationVerificationError.analyticCheckFailed }
        let x = c.point[0], y = c.point[1], lambda = c.equalityMultipliers[0]
        try require(result.status == .optimal && result.uniqueness == .strictConvexity)
        try require(abs(x - 1) < 1e-8 && abs(y) < 1e-8 && abs(x + y - 1) < 1e-8)
        try require(abs(x*x + x*y + y*y - 3*x + 2) < 1e-8 && abs(c.objective + 2) < 1e-8)
        try require(abs(2*x + y - 3 + lambda - c.lowerMultipliers[0] + c.upperMultipliers[0]) < 1e-8)
        try require(abs(x + 2*y + lambda - c.lowerMultipliers[1] + c.upperMultipliers[1]) < 1e-8)
        try require(abs(lambda - 1) < 1e-8 && abs(c.lowerMultipliers[1] - 2) < 1e-8)
        for i in 0..<2 {
            try require(c.lowerMultipliers[i] >= 0 && c.upperMultipliers[i] >= 0)
            try require(abs(c.lowerMultipliers[i]*c.point[i]) + abs(c.upperMultipliers[i]*(c.point[i]-2)) < 1e-8)
        }
    }

    @inline(never)
    private static func verifyInfeasibilityAndRefusal() throws {
        let p = try ConvexOptimizationProblem(metadata: OptimizationProbeContext.metadata(variables: 1, inequality: true),
            linearCost: [0], inequalities: OptimizationProbeContext.row([1]), inequalityRightHandSide: [-1],
            lowerBounds: [0], upperBounds: [2])
        var workspace = EnumerationWorkspace(), work = try OptimizationProbeContext.work()
        let solver: any OptimizationSolving = CompleteConvexOptimizer()
        let result = try solver.solve(p, policy: OptimizationProbeContext.policy(), workspace: &workspace, work: &work)
        guard let f = result.infeasibility else { throw FoundationVerificationError.analyticCheckFailed }
        try require(result.status == .infeasible && result.optimum == nil && result.physicalPoint == nil)
        try require(f.inequalityWeights[0] >= 0 && f.lowerWeights[0] >= 0 && f.upperWeights[0] >= 0)
        let normal = f.inequalityWeights[0] - f.lowerWeights[0] + f.upperWeights[0]
        let rhs = -f.inequalityWeights[0] + 2*f.upperWeights[0]
        try require(abs(normal) < 1e-8 && rhs < -0.9 && f.strictSeparationMargin > f.threshold)
        var refusedWorkspace = EnumerationWorkspace(), refusedWork = try OptimizationProbeContext.work(), refused = false
        let refusedPolicy = try OptimizationProbeContext.policy(candidates: 0)
        do throws(OptimizationFailure) {
            _ = try solver.solve(p, policy: refusedPolicy,
                workspace: &refusedWorkspace, work: &refusedWork)
        } catch {
            guard case .nonconverged(let processed, let limit) = error.cause else { throw FoundationVerificationError.analyticCheckFailed }
            try require(processed == 0 && limit == 0 && !error.failedSupplierWorkUnavailable)
            refused = true
        }
        try require(refused && p.lowerBounds == [0] && p.upperBounds == [2] && p.inequalityRightHandSide == [-1])
    }
}
