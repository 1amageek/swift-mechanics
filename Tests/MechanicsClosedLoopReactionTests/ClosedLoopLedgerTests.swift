import SwiftMechanics
import Testing

@Suite struct ClosedLoopLedgerTests {
    @Test(arguments:[false,true],[0,2]) func actualAssemblyWorkCannotBeReset(fails:Bool,prefix:Int) throws {
        let input=try LoopFixtures.input(gravity:true),policy=try LoopFixtures.policy(),frame=input.geometry.model.tree.worldFrame
        for mode in [LoopEquationFault.Mode.resetNumerical,.resetLoads] {
            var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
            try work.chargeOperations(prefix);try loads.charge(prefix)
            do throws(ClosedLoopReactionError) {
                _=try ClosedLoopReactionRecovery(equations:LoopEquationFault(mode:mode,fails:fails)).recover(input,
                    outputFrame:frame,policy:policy,loadWork:&loads,work:&work)
                Issue.record("Actual assembly/gravity work was erased.")
            } catch {
                if case .supplierLedgerReplaced=error {} else { Issue.record("Expected supplier ledger rejection.") }
                #expect(error.failedSupplierWorkUnavailable)
            }
            #expect(work.operations>prefix)
            // A numerical reset cannot erase the known three-body gravity work in the other ledger.
            #expect(loads.consumed == prefix+1+(mode == .resetNumerical ? 3 : 0))
        }
    }
    @Test func ordinarySupplierFailurePreservesKnownNumericalAndGravityWork() throws {
        let input=try LoopFixtures.input(gravity:true),policy=try LoopFixtures.policy()
        var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
        do throws(ClosedLoopReactionError) {
            _=try ClosedLoopReactionRecovery(equations:LoopEquationFault(mode:.unchanged,fails:true)).recover(input,
                outputFrame:input.geometry.model.tree.worldFrame,policy:policy,loadWork:&loads,work:&work)
            Issue.record("Supplier failure was swallowed.")
        } catch { if case .dynamics(.invalidInput)=error {} else { Issue.record("Expected original supplier failure.") } }
        #expect(work.operations>0 && loads.consumed == 4)
    }
    @Test func callerLoadCancellationClosureSurvivesEqualLimitReplacement() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,visionOS 2.0,*) else {
            Issue.record("Required Mutex platform baseline unavailable.");return
        }
        let input=try LoopFixtures.input(gravity:true),policy=try LoopFixtures.policy(),flag=LoopCancellationFlag()
        var work=try LoopFixtures.work(),loads=try LoopFixtures.loads(cancelled:{flag.isCancelled})
        let supplier=LoopEquationFault(mode:.replaceCancellation,onAssembly:{flag.cancel()})
        do throws(ClosedLoopReactionError) {
            _=try ClosedLoopReactionRecovery(equations:supplier).recover(input,outputFrame:input.geometry.model.tree.worldFrame,
                policy:policy,loadWork:&loads,work:&work)
            Issue.record("Supplier disabled caller cancellation.")
        } catch {
            if case .loadLedgerMerge(.cancelled)=error {} else { Issue.record("Expected retained cancellation closure.") }
            #expect(error.failedSupplierWorkUnavailable)
        }
        #expect(loads.budget.isCancelled() && loads.consumed == 1)
        #expect(work.operations>0)
    }
}
