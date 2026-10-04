import SwiftMechanics
import Testing

@Suite struct PlanarClosedLoopLedgerTests {
    @Test(.timeLimit(.minutes(1)),arguments:[false,true],[0,3]) func actualPhysicalAssemblyResetRetainsKnownPrefixes(fails:Bool,prefix:Int) throws {
        let input=try PlanarLoopFixtures.input(fourbar:false,gravity:true),policy=try PlanarLoopFixtures.policy(2)
        for mode in [PlanarLoopEquationFault.Mode.resetNumerical,.resetLoads] {
            var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
            try work.chargeOperations(prefix);try loads.charge(prefix)
            do throws(ClosedLoopReactionError) {
                _=try PlanarClosedLoopReactionRecovery(equations:PlanarLoopEquationFault(mode:mode,fails:fails)).recover(input,
                    outputFrame:input.geometry.model.tree.worldFrame,policy:policy,loadWork:&loads,work:&work)
                Issue.record("Actual original equation/gravity work was erased")
            } catch {
                if case .supplierLedgerReplaced=error {} else { Issue.record("Unexpected reset refusal") }
                #expect(error.failedSupplierWorkUnavailable)
            }
            #expect(work.operations>prefix)
            #expect(loads.consumed == prefix+1+(mode == .resetNumerical ? 3 : 0))
        }
    }
    @Test(.timeLimit(.minutes(1))) func ordinaryPhysicalSupplierFailureRetainsKnownWork() throws {
        let input=try PlanarLoopFixtures.input(fourbar:false,gravity:true),policy=try PlanarLoopFixtures.policy(2)
        var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
        do throws(ClosedLoopReactionError) {
            _=try PlanarClosedLoopReactionRecovery(equations:PlanarLoopEquationFault(mode:.unchanged,fails:true)).recover(input,
                outputFrame:input.geometry.model.tree.worldFrame,policy:policy,loadWork:&loads,work:&work)
            Issue.record("Original supplier failure was swallowed")
        } catch { if case .dynamics(.invalidInput)=error {} else { Issue.record("Unexpected supplier failure") } }
        #expect(work.operations>0 && loads.consumed == 4)
    }
    @Test(.timeLimit(.minutes(1))) func originalCallerCancellationCannotBeReplacedAtMerge() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,visionOS 2.0,*) {
            let input=try PlanarLoopFixtures.input(fourbar:false,gravity:true),policy=try PlanarLoopFixtures.policy(2),flag=LoopCancellationFlag()
            var work=try LoopFixtures.work(),loads=try LoopFixtures.loads(cancelled:{flag.isCancelled})
            do throws(ClosedLoopReactionError) {
                _=try PlanarClosedLoopReactionRecovery(equations:PlanarLoopEquationFault(mode:.replaceCancellation,onAssembly:{flag.cancel()})).recover(input,
                    outputFrame:input.geometry.model.tree.worldFrame,policy:policy,loadWork:&loads,work:&work)
                Issue.record("Supplier replaced original caller cancellation")
            } catch {
                if case .loadLedgerMerge(.cancelled)=error {} else { Issue.record("Unexpected cancellation merge failure") }
                #expect(error.failedSupplierWorkUnavailable)
            }
            #expect(loads.budget.isCancelled() && loads.consumed == 1 && work.operations>0)
        }
    }
}
