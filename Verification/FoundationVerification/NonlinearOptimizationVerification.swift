import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    static func verifyNonlinearOptimization() throws {
        let context = try NonlinearOptimizationProbeContext()
        let result = try context.solve()
        try require(result.point.count == 2 && result.equalityMultipliers.count == 1)
        let x = result.point[0], y = result.point[1], multiplier = result.equalityMultipliers[0]
        try require(abs(x - 1) < 1e-8 && abs(y - 1) < 1e-8 && abs(multiplier - 1) < 1e-8)
        try require(abs(x*x - y) < 1e-8)
        try require(abs(x - 3 + 2*x*multiplier) < 1e-8 && abs(y - multiplier) < 1e-8)
        let objective = ((x - 3)*(x - 3) + y*y)/2
        try require(abs(objective - 2.5) < 1e-8 && abs(result.objective - objective) < 1e-8)
        let proof = result.proof
        try require(proof.activeRank == 1 && proof.tangentDimension == 1)
        try require(proof.nullspaceBasis.count == 2 && proof.reducedLagrangianHessian.count == 1)
        let first = proof.nullspaceBasis[0], second = proof.nullspaceBasis[1]
        try require(first*first + second*second > 1e-10 && abs(2*x*first - second) < 1e-8)
        let originalCurvature = (1 + 2*multiplier)*first*first + second*second
        try require(originalCurvature > 0 && abs(proof.reducedLagrangianHessian[0] - originalCurvature) < 1e-8)
        try require(proof.primalResidual <= proof.primalThreshold && proof.stationarityResidual <= proof.stationarityThreshold)
        try require(result.work.operations > 0 && result.work.iterations > 0)

        let maximum = try NonlinearOptimizationProbeContext(negativeCurvature: true)
        var refused = false
        do throws(LocalOptimizationFailure) {
            _ = try maximum.solve()
        } catch {
            guard case .numerical(.nonPositiveDefinite) = error.cause else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            refused = true
        }
        try require(refused)
        print("Nonlinear optimization public verification passed: original KKT, nonzero constraint Hessian and local-maximum refusal.")
    }
}
