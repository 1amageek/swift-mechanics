import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct IdentificationBudgetTests {
    @Test func observationMetadataAndModelLimitsBoundTheirActualPhases() throws {
        let p=try IdentificationFixtures.problem()
        for policy in [try IdentificationFixtures.policy(observations:1),try IdentificationFixtures.policy(metadata:0),try IdentificationFixtures.policy(models:0)] {
            let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,policy:policy) }
            guard case .capacity=f.cause else { Issue.record("Expected caller capacity refusal");continue }
            #expect(f.modelValidationAttempts == 0 && f.loadWork.consumed == 0)
        }
        let long=try IdentificationFixtures.source(key:String(repeating:"same-prefix-",count:1000))
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(IdentificationFixtures.problem(source:long),policy:IdentificationFixtures.policy(metadata:20)) }
        guard case .capacity=f.cause else { Issue.record("Expected bounded metadata traversal");return }
        #expect(f.phase == .admission && f.work.operations <= 40 && f.modelValidationAttempts == 0)
    }
    @Test func numericalOperationsStorageAndIterationsAreIndependentLimits() throws {
        let p=try IdentificationFixtures.problem()
        for choice in 0..<3 {
            var workspace=IdentificationWorkspace(),loads=try IdentificationFixtures.loadWork(),calls=try IdentificationFixtures.calls()
            var work=try IdentificationFixtures.work(operations:choice == 0 ? 0 : 10000000,storage:choice == 1 ? 0 : 1000000,iterations:choice == 2 ? 0 : 1000)
            let f=try IdentificationFixtures.failure {
                try PhysicalMassDamperIdentifier().estimate(p,policy:IdentificationFixtures.policy(),workspace:&workspace,loadWork:&loads,supplierWork:&calls,work:&work)
            }
            if choice == 2 {
                guard case .optimization(let failed)=f.cause,case .numerical(.resourceLimit)=failed.cause else { Issue.record("Expected nested iteration refusal");continue }
            } else {
                guard case .numerical(.resourceLimit)=f.cause else { Issue.record("Expected numerical budget refusal");continue }
            }
            #expect(f.work.operations <= work.budget.arithmeticOperations && f.work.iterations <= work.budget.iterations)
            if choice == 2 { #expect(f.phase == .optimization) }
        }
    }
    @Test func loadAndDerivativeCallLimitsDoNotBecomeSilentZeroProducts() throws {
        let p=try IdentificationFixtures.problem()
        for choice in 0..<2 {
            var workspace=IdentificationWorkspace(),loads=try IdentificationFixtures.loadWork(maximum:choice == 0 ? 0 : 10000)
            var calls=try IdentificationFixtures.calls(maximum:choice == 1 ? 0 : 10000),work=try IdentificationFixtures.work()
            let f=try IdentificationFixtures.failure {
                try PhysicalMassDamperIdentifier().estimate(p,policy:IdentificationFixtures.policy(),workspace:&workspace,loadWork:&loads,supplierWork:&calls,work:&work)
            }
            if choice == 0 { guard case .loads(.workExhausted)=f.cause else { Issue.record("Expected load limit");continue } }
            else { guard case .derivative(.capacityExceeded)=f.cause else { Issue.record("Expected derivative-call limit");continue } }
            #expect(f.phase == .physicalDesign && !f.failedSupplierWorkUnavailable)
        }
    }
    @Test func zeroCandidatePolicyPreservesTypedOptimizerFailure() throws {
        let p=try IdentificationFixtures.problem()
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,policy:IdentificationFixtures.policy(candidates:0)) }
        guard case .optimization=f.cause else { Issue.record("Expected optimizer candidate refusal");return }
        #expect(f.phase == .optimization && f.work.operations > 0 && f.modelValidationAttempts == 2)
    }
    @Test func cancellationBeforeAdmissionLeavesCallerWorkAndStateUntouched() throws {
        let p=try IdentificationFixtures.problem()
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,policy:IdentificationFixtures.policy(cancelled:true)) }
        guard case .cancelled=f.cause else { Issue.record("Expected cancellation");return }
        #expect(f.phase == .admission && f.work.operations == 0 && f.loadWork.consumed == 0 && f.supplierWork.calls == 0)
        #expect(p.observations[0].state.q == [0] && p.observations[0].state.v == [1])
    }
}
