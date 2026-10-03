import Testing
import MechanicsCore
import MechanicsNumerics
import MechanicsOptimization
struct ConvexOptimumTests {
    @Test func sparseLinearProgramHasIndependentPrimalDualOptimum() throws {
        let problem=try OptimizationFixtures.problem(cost:[-1,-2],inequality:[[1,1]],ineqRHS:[1])
        let result=try OptimizationFixtures.solve(problem)
        let c=try #require(result.optimum)
        #expect(result.status == .optimal && result.uniqueness == .notEstablished)
        #expect(OptimizationFixtures.close(c.point[0],0) && OptimizationFixtures.close(c.point[1],1))
        #expect(OptimizationFixtures.close(c.objective,-2))
        #expect(OptimizationFixtures.close(c.inequalityMultipliers[0],2) && OptimizationFixtures.close(c.lowerMultipliers[0],1))
        let sx = -1+c.inequalityMultipliers[0]-c.lowerMultipliers[0]+c.upperMultipliers[0]
        let sy = -2+c.inequalityMultipliers[0]-c.lowerMultipliers[1]+c.upperMultipliers[1]
        #expect(abs(sx)+abs(sy) < 1e-8)
        #expect(c.point[0]+c.point[1] <= 1+1e-8 && c.point[0] >= -1e-8 && c.point[1] >= -1e-8)
        #expect(result.processedBases == 10)
    }
    @Test func strictConvexQpUsesActualIndefiniteKktAndOriginalMultipliers() throws {
        let p=try OptimizationFixtures.problem(cost:[-3,0],hessian:[2,1,1,2],equality:[[1,1]],eqRHS:[1])
        let result=try OptimizationFixtures.solve(p), c=try #require(result.optimum)
        #expect(result.uniqueness == .strictConvexity)
        #expect(OptimizationFixtures.close(c.point[0],1) && OptimizationFixtures.close(c.point[1],0))
        #expect(OptimizationFixtures.close(c.objective,-2))
        #expect(OptimizationFixtures.close(c.equalityMultipliers[0],1) && OptimizationFixtures.close(c.lowerMultipliers[1],2))
        #expect(abs(2*c.point[0]+c.point[1]-3+c.equalityMultipliers[0]-c.lowerMultipliers[0]+c.upperMultipliers[0]) < 1e-8)
        #expect(abs(c.point[0]+2*c.point[1]+c.equalityMultipliers[0]-c.lowerMultipliers[1]+c.upperMultipliers[1]) < 1e-8)
        #expect(result.processedBases == 5)
    }
    @Test func tiedLpDoesNotInventReactionOrUniqueness() throws {
        let p=try OptimizationFixtures.problem(cost:[-1,-1],inequality:[[1,1]],ineqRHS:[1])
        let result=try OptimizationFixtures.solve(p), c=try #require(result.optimum)
        #expect(result.uniqueness == .notEstablished && OptimizationFixtures.close(c.objective,-1))
        #expect(OptimizationFixtures.close(c.point[0]+c.point[1],1))
        // Two independent feasible points with equal objective falsify any unique-solution claim.
        let firstObjective: Double=p.linearCost[0]*0.0+p.linearCost[1]*1.0
        let secondObjective: Double=p.linearCost[0]*1.0+p.linearCost[1]*0.0
        #expect(firstObjective == secondObjective)
    }
    @Test func physicalReferenceMappingPreservesNormalizedOriginalProblem() throws {
        let p=try OptimizationFixtures.problem(cost:[-1,-2],inequality:[[1,1]],ineqRHS:[1],variableScales:[2,4],costScale:3)
        let result=try OptimizationFixtures.solve(p), physical=try #require(result.physicalPoint), objective=try #require(result.physicalObjective)
        #expect(OptimizationFixtures.close(physical[0],0) && OptimizationFixtures.close(physical[1],4))
        #expect(OptimizationFixtures.close(objective,-6))
        #expect(result.metadata.variableReferences[1].dimension == .length && result.metadata.objectiveReference.dimension == .energy)
        #expect(p.inequalities?.values == [1,1] && p.linearCost == [-1,-2])
    }
    @Test func fixedBoundsAndDependentCandidateRowsAreHandledWithoutFailedLuRetry() throws {
        let p=try OptimizationFixtures.problem(cost:[1],lower:[0.5],upper:[0.5])
        let result=try OptimizationFixtures.solve(p), c=try #require(result.optimum)
        #expect(OptimizationFixtures.close(c.point[0],0.5) && OptimizationFixtures.close(c.objective,0.5))
        #expect(result.processedBases == 2)
        let redundant=try OptimizationFixtures.problem(cost:[-1,-2],inequality:[[1,1],[2,2]],ineqRHS:[1,2])
        let duplicateResult=try OptimizationFixtures.solve(redundant)
        #expect(OptimizationFixtures.close(try #require(duplicateResult.optimum).objective,-2))
        #expect(duplicateResult.processedBases == 15)
    }
    @Test func interiorQpAndConstantCostRequireZeroActiveRowsCandidate() throws {
        let base=try OptimizationFixtures.problem(cost:[-1],hessian:[2])
        let p=ConvexOptimizationProblem(metadata:base.metadata,linearCost:base.linearCost,constantCost:7,hessian:base.hessian,
            lowerBounds:base.lowerBounds,upperBounds:base.upperBounds)
        let result=try OptimizationFixtures.solve(p), c=try #require(result.optimum)
        #expect(OptimizationFixtures.close(c.point[0],0.5)); #expect(OptimizationFixtures.close(c.objective,6.75))
        #expect(c.lowerMultipliers[0] == 0 && c.upperMultipliers[0] == 0)
        #expect(result.processedBases == 3 && result.uniqueness == .strictConvexity)
    }
    @Test func zeroObjectiveFeasibleProblemStillProducesOriginalCertificate() throws {
        let p=try OptimizationFixtures.problem(cost:[0,0],inequality:[[1,1]],ineqRHS:[1])
        let result=try OptimizationFixtures.solve(p), c=try #require(result.optimum)
        #expect(c.objective == 0 && c.primalResidual <= c.primalThreshold && c.stationarityResidual <= c.stationarityThreshold)
    }
}
