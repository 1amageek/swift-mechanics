import SwiftMechanics
import Testing

@Suite struct LoadedSleepFailureTests {
    @Test(arguments:[0,1,2,3]) func invocationWorkCapacityAndCancellationPreserveAcceptedPrefix(mode:Int) throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try LoadedSleepFixtures.model(),owner=try LoadedSleepFixtures.owner(model),session=try LoadedSleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };let before=session.snapshot()
            let budget=try LoadedSleepFixtures.budget(work:mode == 1 ? 5 : 100,scalars:mode == 2 ? 1 : 2,cancelled:mode == 3)
            do throws(LoadedMechanismSleepFailure) {
                _=try owner.stepWithLoads(session,loadBudget:budget,maximumLoadInvocations:mode == 0 ? 0 : 64)
                Issue.record("Invalid load invocation envelope was accepted.")
            } catch {
                #expect(error.accepted == before);#expect(!error.failedSupplierWorkUnavailable)
                if mode == 0 { #expect(error.loads.invocationsStarted == 0);#expect(error.loads.consumed == 0) }
                if mode == 1 { #expect(error.loads.invocationsStarted == 1);#expect(error.loads.consumed == 5) }
                if mode == 2 { #expect(error.loads.invocationsStarted == 1);#expect(error.loads.consumed == 0);#expect(error.loads.peakScalars == 0) }
                if mode == 3 { #expect(error.loads.consumed == 0) }
            }
            #expect(session.snapshot() == before);#expect(session.snapshot().checkpoint.random == before.checkpoint.random)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func failedSelectionAndRejectedTrialPreserveSelectedHistoryAndRandom() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try LoadedSleepFixtures.model(),owner=try LoadedSleepFixtures.owner(model,dwell:0),session=try LoadedSleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };_=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            let before=session.snapshot(),failingBudget=try LoadedSleepFixtures.budget(work:4);var work=try LoadedSleepFixtures.work()
            do throws(LoadedMechanismSleepFailure) {
                _=try owner.selectLoad(session,expected:before,selection:StationaryLoadSelection(programID:2,revision:1,generation:1),loadBudget:failingBudget,maximumLoadInvocations:1,work:&work)
                Issue.record("Insufficient physical load work unexpectedly published selection.")
            } catch { #expect(error.loads.consumed == 4);#expect(error.loads.invocationsStarted == 1) }
            #expect(session.snapshot() == before)
            _=try session.performTrial { (trial,control) throws(RuntimeFailure) in
                try control.beginWorkBlock(units:1);_=try trial.nextRandom();try trial.setVelocity(5,at:0)
                let old=try trial.contributor(owner.schema.id)
                try trial.replaceContributor(RuntimeContributorState(id:old.id,category:old.category,version:old.version,bytes:[]))
                return .reject
            }
            #expect(session.snapshot() == before)
            #expect(try LoadedSleepFixtures.history(owner,before).selection.generation == 0)
            let omitted=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(work:0),maximumLoadInvocations:0)
            #expect(omitted.loads.consumed == 0);#expect(omitted.integration.accepted.checkpoint.random == before.checkpoint.random)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test(arguments:[false,true]) func supplierResetPreservesKnownLoadMarkerAndStopsRetry(failed:Bool) throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try LoadedSleepFixtures.model(),catalog=try LoadedSleepFixtures.catalog(model)
            let execution=try StationaryLoadExecution(scope:.equationExecution,budget:LoadedSleepFixtures.budget(),maximumInvocations:2,requiredScalars:2)
            let invocation=try execution.beginInvocation();var work=invocation.initialWork
            _=try ReferenceStationaryLoadEvaluator().evaluate(catalog.program(StationaryLoadSelection(programID:1,revision:1,generation:0)),catalog:catalog,physical:model.descriptor.initialState,work:&work)
            #expect(work.consumed == 3)
            work=LoadWork(budget:invocation.initialWork.budget)
            #expect(throws:StationaryLoadError.self) { try execution.finishInvocation(invocation,work:work,failedSupplierWorkUnavailable:failed) }
            let known=execution.report()
            #expect(known.consumed == 1);#expect(known.peakScalars == 2);#expect(known.failedSupplierWorkUnavailable)
            #expect(known.invocationsStarted == 1);#expect(known.invocationsCompleted == 1)
            #expect(throws:StationaryLoadError.self) { _=try execution.beginInvocation() }
            let closed=execution.close();#expect(closed.consumed == 1);#expect(closed.invocationsStarted == 1)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func unknownSupplierFailureAndOutstandingLeaseKeepActualPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let execution=try StationaryLoadExecution(scope:.equationExecution,budget:LoadedSleepFixtures.budget(),maximumInvocations:2,requiredScalars:2)
            let invocation=try execution.beginInvocation();var work=invocation.initialWork;try work.charge(2)
            try execution.finishInvocation(invocation,work:work,failedSupplierWorkUnavailable:true)
            #expect(execution.report().consumed == 3);#expect(execution.report().failedSupplierWorkUnavailable)
            #expect(throws:StationaryLoadError.self) { _=try execution.beginInvocation() };_=execution.close()
            let pending=try StationaryLoadExecution(scope:.equationExecution,budget:LoadedSleepFixtures.budget(),maximumInvocations:2,requiredScalars:2)
            let lease=try pending.beginInvocation();let closed=pending.close()
            #expect(closed.consumed == 1);#expect(closed.failedSupplierWorkUnavailable)
            var late=lease.initialWork;try late.charge(2)
            #expect(throws:StationaryLoadError.self) { try pending.finishInvocation(lease,work:late,failedSupplierWorkUnavailable:false) }
            #expect(pending.report().consumed == 3)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func closeReentryDuringAdmissionCannotPublishASupplierLease() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let cancellation=LoadedExecutionClosingCancellation()
            let budget=try LoadBudget(maximumWork:100,maximumScalars:2,isCancelled:{cancellation.closeDuringCallback()})
            let execution=try StationaryLoadExecution(scope:.equationExecution,budget:budget,maximumInvocations:2,requiredScalars:2)
            cancellation.bind(execution)
            #expect(throws:StationaryLoadError.self) { _=try execution.beginInvocation() }
            let actual=execution.report()
            #expect(actual.consumed == 1);#expect(actual.peakScalars == 2)
            #expect(actual.invocationsStarted == 1);#expect(actual.invocationsCompleted == 1)
            #expect(actual.failedSupplierWorkUnavailable)
            #expect(throws:StationaryLoadError.self) { _=try execution.beginInvocation() }
            #expect(execution.close().consumed == 1)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }

}
