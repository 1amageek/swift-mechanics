@testable import SwiftMechanics
import Testing

@Suite struct PrescribedRootAggregateTests {
    @Test func actualRootColdSolveAdmitsOneAggregateBeforeOpaqueWorkAndKeepsTerminalPrefixes() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try PrescribedRootEvolutionFixture(planar:false),initial=fixture.model.descriptor.initialState
            let budget=try NumericalBudget(scalarStorage:4_000_000,arithmeticOperations:1_000_003,iterations:403)
            for fail in [false,true] {
                let supplier=PrescribedRootAggregateSolver(fail:fail),equation=try fixture.equation(solver:supplier)
                var work=NumericalWork(budget:budget);try work.chargeOperations(5001);try work.advanceIteration();try work.advanceIteration()
                do throws(RuntimeFailure) { try equation.validateStoredPhysical(initial,acceptedSteps:0,work:&work);Issue.record("Exhausted original acceptance published") }
                catch { #expect(error.code == (fail ? .invalidState : .capacityExceeded));#expect(!error.failedSupplierWorkUnavailable) }
                let evidence=try #require(supplier.evidence())
                #expect(evidence.delegated && evidence.arithmetic <= budget.arithmeticOperations-5001-4)
                #expect(evidence.iterations == budget.iterations-2)
                #expect(work.operations == budget.arithmeticOperations && work.iterations == budget.iterations)
            }
        }
    }
    @Test func firstResetRetainsAllOtherActualSolverPrefixesAndItsAdmissionSeed() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try PrescribedRootEvolutionFixture(planar:false),supplier=PrescribedRootAggregateSolver(fail:true,reset:true)
            let equation=try fixture.equation(solver:supplier),budget=try NumericalBudget(scalarStorage:4_000_000,arithmeticOperations:1_000_003,iterations:403)
            var work=NumericalWork(budget:budget)
            do throws(RuntimeFailure) { try equation.validateStoredPhysical(fixture.model.descriptor.initialState,acceptedSteps:0,work:&work);Issue.record("Reset supplier accepted") }
            catch { #expect(error.code == .invalidOwnerAccess && error.failedSupplierWorkUnavailable) }
            let evidence=try #require(supplier.evidence()),known=try #require(evidence.knownPrefix)
            #expect(evidence.delegated && known > 4)
            #expect(work.operations == budget.arithmeticOperations-evidence.arithmetic+known)
            #expect(work.operations <= budget.arithmeticOperations)
        }
    }

}
