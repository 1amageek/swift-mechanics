import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PlanarPrescribedRootReactionLedgerTests {
    @Test(arguments:[false,true], [false,true])
    func gravityActualWorkResetPreservesZeroAndPrechargedPrefixes(precharged: Bool, fails: Bool) throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures(slider:true,gravity:true),prefix=precharged ? 7 : 0
            var work=try PlanarPrescribedRootReactionFixtures.work(),loads=try PlanarPrescribedRootReactionFixtures.loads(prefix:prefix)
            let recovery=PlanarPrescribedRootReactionRecovery(gravity:ReactionErasingGravity(failAfterReset:fails))
            do throws(PlanarPrescribedRootReactionError) {
                _=try recovery.recover(f.input,outputFrame:f.model.tree.worldFrame,policy:f.policy,loadWork:&loads,work:&work)
                Issue.record("Actual gravity work reset accepted")
            } catch { if case .supplierLedgerReplaced=error { #expect(error.failedSupplierWorkUnavailable) } else { Issue.record("Wrong load reset rejection") } }
            #expect(loads.consumed == prefix+1)
            // A valid callback keeps admission + actual point + original point for both bodies.
            let result=try PlanarPrescribedRootReactionRecovery().recover(f.input,outputFrame:f.model.tree.worldFrame,policy:f.policy,loadWork:&loads,work:&work)
            #expect(result.loadWork.consumed == prefix+7)
        }
    }
    @Test(arguments:[PlanarPrescribedRootForeignEquations.Query.force,.body], [false,true])
    func actualNumericalQueryResetSuccessAndFailure(query: PlanarPrescribedRootForeignEquations.Query, fails: Bool) throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures()
            var work=try PlanarPrescribedRootReactionFixtures.work(),loads=try PlanarPrescribedRootReactionFixtures.loads()
            try work.chargeOperations(7);let prefix=work.operations
            let recovery=PlanarPrescribedRootReactionRecovery(equations:PlanarPrescribedRootForeignEquations(query:query,reset:true,fails:fails))
            do throws(PlanarPrescribedRootReactionError) {
                _=try recovery.recover(f.input,outputFrame:f.model.tree.worldFrame,policy:f.policy,loadWork:&loads,work:&work)
                Issue.record("Actual numerical work reset accepted")
            } catch { if case .supplierLedgerReplaced=error { #expect(error.failedSupplierWorkUnavailable) } else { Issue.record("Wrong numerical reset rejection") } }
            #expect(work.operations > prefix)
        }
    }
    @Test func foreignInertiaAndGravityOriginalSourcesCannotPassMetadata() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures(),foreign=try PlanarPrescribedRootReactionFixtures.foreign(f.constraint.system)
            for query in [PlanarPrescribedRootForeignEquations.Query.force,.body] {
                var work=try PlanarPrescribedRootReactionFixtures.work(),loads=try PlanarPrescribedRootReactionFixtures.loads()
                let recovery=PlanarPrescribedRootReactionRecovery(equations:PlanarPrescribedRootForeignEquations(query:query,foreign:foreign))
                do throws(PlanarPrescribedRootReactionError) {
                    _=try recovery.recover(f.input,outputFrame:f.model.tree.worldFrame,policy:f.policy,loadWork:&loads,work:&work)
                    Issue.record("Foreign inertia accepted under original IDs/frame/reference")
                } catch { if case .invalidSupplierEvidence=error {} else { Issue.record("Wrong original inertia rejection") } }
            }
            let slider=try PlanarPrescribedRootReactionFixtures(slider:true,gravity:true)
            let field=try AffineGravity(frame:slider.model.tree.worldFrame,accelerationAtOrigin:Vector3(0,-20,0))
            var work=try PlanarPrescribedRootReactionFixtures.work(),loads=try PlanarPrescribedRootReactionFixtures.loads()
            let recovery=PlanarPrescribedRootReactionRecovery(gravity:PlanarPrescribedRootGravitySupplier(foreign:field))
            do throws(PlanarPrescribedRootReactionError) {
                _=try recovery.recover(slider.input,outputFrame:slider.model.tree.worldFrame,policy:slider.policy,loadWork:&loads,work:&work)
                Issue.record("Foreign gravity accepted")
            } catch { if case .invalidSupplierEvidence=error {} else { Issue.record("Wrong gravity source rejection") } }
            #expect(loads.consumed == 3)
        }
    }
    @Test func validSupplierFailureAndCancellationDuringMergeRetainKnownWork() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures(slider:true,gravity:true)
            var work=try PlanarPrescribedRootReactionFixtures.work(),loads=try PlanarPrescribedRootReactionFixtures.loads(prefix:7)
            let failed=PlanarPrescribedRootReactionRecovery(gravity:PlanarPrescribedRootGravitySupplier(fails:true))
            do throws(PlanarPrescribedRootReactionError) {
                _=try failed.recover(f.input,outputFrame:f.model.tree.worldFrame,policy:f.policy,loadWork:&loads,work:&work)
                Issue.record("Supplier failure published")
            } catch { if case .tree(.loads(.providerFailure(26)))=error {} else { Issue.record("Original supplier cause lost") } }
            #expect(loads.consumed == 9)
            let flag=PlanarReactionCancellationFlag()
            work=try PlanarPrescribedRootReactionFixtures.work();loads=try PlanarPrescribedRootReactionFixtures.loads(prefix:7,cancel:{flag.cancelled})
            let cancelled=PlanarPrescribedRootReactionRecovery(gravity:PlanarReactionCancellingGravity(flag:flag))
            do throws(PlanarPrescribedRootReactionError) {
                _=try cancelled.recover(f.input,outputFrame:f.model.tree.worldFrame,policy:f.policy,loadWork:&loads,work:&work)
                Issue.record("Cancellation during merge published")
            } catch { if case .loadLedgerMerge(.cancelled)=error { #expect(error.failedSupplierWorkUnavailable) } else { Issue.record("Merge cancellation cause lost") } }
            #expect(loads.consumed == 8 && loads.budget.isCancelled())
        }
    }
    @Test func exhaustedWorkAndGravityBudgetsAreTypedAndPreservePrefixes() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures(slider:true,gravity:true)
            var work=try PlanarPrescribedRootReactionFixtures.work(),loads=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0))
            do throws(PlanarPrescribedRootReactionError) {
                _=try PlanarPrescribedRootReactionRecovery().recover(f.input,outputFrame:f.model.tree.worldFrame,policy:f.policy,loadWork:&loads,work:&work)
                Issue.record("Exhausted gravity work published")
            } catch { if case .tree(.loads(.workExhausted))=error {} else { Issue.record("Wrong gravity exhaustion") } }
            #expect(loads.consumed == 0)
            work=try PlanarPrescribedRootReactionFixtures.work(operations:0);loads=try PlanarPrescribedRootReactionFixtures.loads()
            do throws(PlanarPrescribedRootReactionError) {
                _=try PlanarPrescribedRootReactionRecovery().recover(f.input,outputFrame:f.model.tree.worldFrame,policy:f.policy,loadWork:&loads,work:&work)
                Issue.record("Exhausted numerical work published")
            } catch { if case .numerical=error {} else { Issue.record("Wrong numerical exhaustion") } }
            #expect(work.operations == 0)
        }
    }
}
