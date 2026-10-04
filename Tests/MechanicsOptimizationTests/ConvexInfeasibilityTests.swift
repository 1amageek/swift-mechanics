import SwiftMechanics
import Testing
struct ConvexInfeasibilityTests {
    @Test func infeasibleRowsHaveIndependentOriginalFarkasCombination() throws {
        let p=try OptimizationFixtures.problem(cost:[0],inequality:[[1]],ineqRHS:[-1],lower:[0],upper:[2])
        let result=try OptimizationFixtures.solve(p), c=try #require(result.infeasibility)
        #expect(result.status == .infeasible && result.optimum == nil && result.physicalPoint == nil)
        let normal=c.inequalityWeights[0]-c.lowerWeights[0]+c.upperWeights[0]
        let rhs = -c.inequalityWeights[0]+2*c.upperWeights[0]
        #expect(abs(normal) < 1e-8 && rhs < -0.9)
        #expect(c.inequalityWeights[0] >= 0 && c.lowerWeights[0] >= 0 && c.upperWeights[0] >= 0)
        #expect(c.strictSeparationMargin > c.threshold && c.originalNormalResidual <= c.threshold)
        #expect(result.processedBases == 13)
    }
    @Test func equalityOutsideFiniteBoxUsesSignedOriginalWitness() throws {
        let p=try OptimizationFixtures.problem(cost:[0],equality:[[1]],eqRHS:[3],lower:[0],upper:[1])
        let result=try OptimizationFixtures.solve(p), c=try #require(result.infeasibility)
        let normal=c.equalityWeights[0]-c.lowerWeights[0]+c.upperWeights[0]
        let rhs=3*c.equalityWeights[0]+c.upperWeights[0]
        #expect(abs(normal) < 1e-8 && rhs < 0)
        #expect(c.equalityWeights[0] < 0 && c.upperWeights[0] > 0)
        #expect(c.strictSeparationMargin > 0)
    }
}
