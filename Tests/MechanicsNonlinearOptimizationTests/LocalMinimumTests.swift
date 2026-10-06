import SwiftMechanics
import Testing
struct LocalMinimumTests {
    @Test func curvedEqualityUsesNonzeroConstraintHessianAndIndependentTangent() throws {
        let p=try LocalOptimizationFixtures.problem(),r=try LocalOptimizationFixtures.solve(p)
        #expect(abs(r.point[0]-1) < 1e-8 && abs(r.point[1]-1) < 1e-8)
        #expect(abs(r.objective-2.5) < 1e-8 && abs(r.equalityMultipliers[0]-1) < 1e-8)
        let x=r.point[0],y=r.point[1],lambda=r.equalityMultipliers[0]
        let sx: Double=x-3+2*x*lambda,sy: Double=y-lambda
        #expect(abs(x*x-y) < 1e-8 && abs(sx) < 1e-8 && abs(sy) < 1e-8)
        #expect(r.proof.activeRank == 1 && r.proof.tangentDimension == 1)
        let z=r.proof.nullspaceBasis
        #expect(abs(2*x*z[0]-z[1]) < 1e-9)
        let independent: Double=(1+2*lambda)*z[0]*z[0]+z[1]*z[1]
        #expect(abs(independent-r.proof.reducedLagrangianHessian[0]) < 1e-8)
        #expect(abs(r.proof.reducedLagrangianHessian[0]-1.75) < 1e-8)
        #expect(p.initialPoint == [0.8,0.8] && p.initialEqualityMultipliers == [0.8])
        #expect(r.work.operations > 0 && r.work.iterations > 0)
    }
    @Test func activeNonlinearInequalityHasStrictMultiplierAndPositiveTangent() throws {
        let r=try LocalOptimizationFixtures.solve(LocalOptimizationFixtures.problem(.activeCurve))
        #expect(abs(r.point[0]-1) < 1e-8 && abs(r.point[1]) < 1e-8)
        #expect(abs(r.inequalityMultipliers[0]-0.5) < 1e-8 && abs(r.objective-0.5) < 1e-8)
        let stationarity=r.point[0]-2+2*r.point[0]*r.inequalityMultipliers[0]
        #expect(abs(stationarity) < 1e-8 && abs(r.point[0]*r.point[0]-1) < 1e-8)
        #expect(r.proof.activeRank == 1 && r.proof.tangentDimension == 1)
        #expect(abs(r.proof.reducedLagrangianHessian[0]-1) < 1e-8)
    }
    @Test func activeUpperBoundPublishesExplicitVacuousTangent() throws {
        let r=try LocalOptimizationFixtures.solve(LocalOptimizationFixtures.problem(.bound))
        #expect(abs(r.point[0]-1) < 1e-8 && abs(r.upperMultipliers[0]-2) < 1e-8)
        #expect(r.proof.tangentDimension == 0 && r.proof.reducedLagrangianHessian.isEmpty)
        #expect(r.lowerMultipliers[0] == 0 && r.physicalPoint == r.point)
    }
}
