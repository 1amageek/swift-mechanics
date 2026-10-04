@testable import SwiftMechanics
import Testing

@Suite struct ColdAggregateValidationTests {
    @Test(.timeLimit(.minutes(1))) func actualColdSolverSharesOneCallerEnvelopeAndRetainsTerminalKnownPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try MovingBaseFixture(),original=try fixture.equation(),initial=fixture.model.descriptor.initialState
            let state=try KinematicState(revision:initial.revision,time:initial.time,q:initial.q,v:initial.v,
                acceleration:[0.2,0.2],prescribedAnchors:initial.prescribedAnchors)
            let budget=try NumericalBudget(scalarStorage:4_000_000,arithmeticOperations:200_003,iterations:403)
            var preparedOperations:Int?
            for throwsAfterPrefix in [false,true] {
                let solver=ColdAggregateSolver(throwsAfterPrefix:throwsAfterPrefix)
                let equation=try GeometricMechanismEquation(identity:original.descriptor.identity,geometry:fixture.geometry,drive:original.drive,
                    policy:original.policy,projection:original.projection,maximumStageChartCorrection:original.maximumStageChartCorrection,
                    publicationBudget:original.publicationBudget,admission:NonlinearMechanismFixtures.admission(),maximumIdentityBytes:50000,solver:solver)
                var work=NumericalWork(budget:budget);try work.chargeOperations(5001);try work.advanceIteration();try work.advanceIteration()
                do throws(RuntimeFailure) { try equation.validateStoredPhysical(state,acceptedSteps:1,work:&work);Issue.record("Exhausted cold comparison or supplier succeeded") }
                catch {
                    #expect(!error.failedSupplierWorkUnavailable)
                    #expect(error.code == (throwsAfterPrefix ? .invalidState : .capacityExceeded))
                }
                let evidence=try #require(solver.evidence())
                #expect(evidence.delegated)
                #expect(evidence.arithmetic <= budget.arithmeticOperations-5001-4)
                #expect(evidence.iterations == budget.iterations-2)
                #expect(work.operations == budget.arithmeticOperations);#expect(work.iterations == budget.iterations)
                // The one remaining snapshot excludes all four boundary markers; local seeds are already inside it.
                preparedOperations=budget.arithmeticOperations-evidence.arithmetic-4
            }
            let prepared=try #require(preparedOperations),solver=ColdAggregateSolver()
            let equation=try GeometricMechanismEquation(identity:original.descriptor.identity,geometry:fixture.geometry,drive:original.drive,
                policy:original.policy,projection:original.projection,maximumStageChartCorrection:original.maximumStageChartCorrection,
                publicationBudget:original.publicationBudget,admission:NonlinearMechanismFixtures.admission(),maximumIdentityBytes:50000,solver:solver)
            var limited=NumericalWork(budget:try NumericalBudget(scalarStorage:budget.scalarStorage,arithmeticOperations:prepared+7,iterations:budget.iterations))
            try limited.chargeOperations(5001);try limited.advanceIteration();try limited.advanceIteration()
            do throws(RuntimeFailure) { try equation.validateStoredPhysical(state,acceptedSteps:1,work:&limited);Issue.record("Unadmitted cold supplier called") }
            catch { #expect(error.code == .capacityExceeded);#expect(!error.failedSupplierWorkUnavailable) }
            #expect(solver.evidence() == nil);#expect(limited.operations <= limited.budget.arithmeticOperations)
        }
    }
}
