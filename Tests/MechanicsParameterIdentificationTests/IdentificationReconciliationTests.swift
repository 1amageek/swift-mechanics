import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct IdentificationReconciliationTests {
    @Test func simultaneousThreeLedgerResetAfterRealDerivativeRestoresEveryKnownPrefix() throws {
        let p=try IdentificationFixtures.problem()
        for mode in [IdentificationFaultDerivative.Mode.resetAll,.resetAllThenThrow] {
            let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,service:PhysicalMassDamperIdentifier(derivatives:IdentificationFaultDerivative(mode:mode))) }
            guard case .invalidSupplierLedger=f.cause else { Issue.record("Expected authoritative simultaneous ledger refusal");continue }
            #expect(f.phase == .physicalDesign && f.failedSupplierWorkUnavailable)
            #expect(f.work.operations > 0 && f.supplierWork.calls == 1 && f.loadWork.consumed == 2)
        }
    }
    @Test func derivativeCannotReplaceOriginalLoadCancellationAuthority() throws {
        guard #available(macOS 15,iOS 18,tvOS 18,watchOS 11,*) else { return }
        let cancellation=IdentificationCancellationOwner(),p=try IdentificationFixtures.problem()
        let derivative=IdentificationFaultDerivative(mode:.replaceLoadCancellation,didEvaluate:{ cancellation.cancel() })
        var workspace=IdentificationWorkspace(),work=try IdentificationFixtures.work(),calls=try IdentificationFixtures.calls()
        var loads=LoadWork(budget:try LoadBudget(maximumWork:10000,maximumScalars:0,isCancelled:{ cancellation.isCancelled }))
        let f=try IdentificationFixtures.failure {
            try PhysicalMassDamperIdentifier(derivatives:derivative).estimate(p,policy:IdentificationFixtures.policy(),workspace:&workspace,loadWork:&loads,supplierWork:&calls,work:&work)
        }
        guard case .loads(.cancelled)=f.cause else { Issue.record("Expected original load cancellation");return }
        #expect(loads.budget.isCancelled() && f.loadWork.budget.isCancelled())
        #expect(f.phase == .physicalDesign && f.loadWork.consumed == 2 && f.work.operations > 0 && f.supplierWork.calls > 1)
    }
    @Test func successfulDerivativeConsumptionRetainsOriginalCancellationForLaterCallerUse() throws {
        guard #available(macOS 15,iOS 18,tvOS 18,watchOS 11,*) else { return }
        let cancellation=IdentificationCancellationOwner(),p=try IdentificationFixtures.problem()
        var workspace=IdentificationWorkspace(),work=try IdentificationFixtures.work(),calls=try IdentificationFixtures.calls()
        var loads=LoadWork(budget:try LoadBudget(maximumWork:10000,maximumScalars:0,isCancelled:{ cancellation.isCancelled }))
        let service=PhysicalMassDamperIdentifier(derivatives:IdentificationFaultDerivative(mode:.replaceLoadCancellation))
        let result=try service.estimate(p,policy:IdentificationFixtures.policy(),workspace:&workspace,loadWork:&loads,supplierWork:&calls,work:&work)
        #expect(IdentificationFixtures.close(result.massKilograms,2) && loads.consumed == 8 && result.loadWork.consumed == 8)
        cancellation.cancel()
        #expect(loads.budget.isCancelled() && result.loadWork.budget.isCancelled())
        do { try loads.charge(1);Issue.record("Original cancelled budget must refuse later work") }
        catch { guard case .cancelled=error else { Issue.record("Expected original load cancellation");return } }
        #expect(loads.consumed == 8)
    }
}
