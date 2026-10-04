import SwiftMechanics
import Testing

@Suite struct SleepTopologyFailureTests {
    @Test(arguments:[SleepTopologyFaultSolver.Fault.resetSuccess,.resetFailure,.unknown,.knownFailure,.cancelled])
    @available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
    func genuineColdSupplierFailureKeepsSourceRNGAndKnownCallerScope(_ fault:SleepTopologyFaultSolver.Fault) throws {
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() };_=try SleepTopologyFixtures.enter(source)
        let selected=try SleepTopologyFixtures.select(source),prefix=source.session.snapshot(),solver=SleepTopologyFaultSolver(fault)
        let equation=try SleepTopologyFixtures.equation(selected.transition.release.target,target:true,solver:solver)
        #expect(equation.descriptor == selected.equations.descriptor)
        var work=try SleepTopologyFixtures.work();try work.chargeOperations(31)
        do throws(TopologyReleaseFailure) {
            _=try ReferenceSleepTopologyTransitionPreparer().prepare(source:prefix,sourceConfiguration:source.session.configuration,
                retirement:selected.retirement,transition:selected.transition,history:source.history,observation:.explicit(selected.transition.release),ruleID:1,
                dispositions:[.appendHistory,.retireSleep,.initializeGlobalIntegration(retiredID:source.owner.continuation.schema.id)],
                targetConfiguration:selected.prepared.configuration,equations:equation,continuation:selected.continuation,validationBudget:work.budget,cancellation:nil,work:&work)
            Issue.record("A failed/reset genuine target supplier was admitted.")
        } catch {
            switch fault {
            case .resetSuccess,.resetFailure,.unknown:#expect(error.failedSupplierWorkUnavailable)
            case .knownFailure,.cancelled:#expect(!error.failedSupplierWorkUnavailable)
            }
            if case .runtime(let original)=error { #expect(original.lastAccepted == prefix) } else { Issue.record("Original Runtime failure was not retained.") }
        }
        #expect(solver.invocationCount() == 1);#expect(work.operations > 31)
        #expect(source.session.snapshot() == prefix);#expect(source.session.snapshot().checkpoint.random == prefix.checkpoint.random)
    }
    @Test func coldHandlerCannotUseGenuineDifferentLawTokenToBypassRetirement() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() };_=try SleepTopologyFixtures.enter(source)
        let selected=try SleepTopologyFixtures.select(source),prefix=source.session.snapshot(),release=selected.transition.release
        let changed=try SleepTopologyFixtures.equation(release.target,target:true,effort:-8)
        var work=try SleepTopologyFixtures.work()
        let token=try ReferenceNonlinearSubtreeAccelerationPreparer().prepare(release:release,equations:changed,work:&work)
        let history=try source.history.appending(source:prefix,target:token,observation:.explicit(release),ruleID:1)
        let wake=try SleepTopologyWakeContributor(retirement:selected.retirement,transition:token,history:history,ruleID:1,policy:SleepTopologyFixtures.historyPolicy(),work:&work)
        let integration=try IntegrationContinuationProvider(descriptor:changed.descriptor,policy:SleepTopologyFixtures.integration(changed.descriptor))
        let registry=try TopologyRuntimeContributors(providers:[history,wake,integration],capacity:source.session.configuration.capacity)
        let base=TopologyCheckpointHandler(history:history,contributors:registry)
        #expect(throws:RuntimeFailure.self) {
            try SleepTopologyCheckpointHandler(wake:wake,history:history,equations:changed,continuation:integration,base:base,validationBudget:work.budget)
        }
        #expect(source.session.snapshot() == prefix)
    }
    @Test func capacityBeforePhysicalAdmissionDoesNotInvokeTargetSupplier() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() };_=try SleepTopologyFixtures.enter(source)
        let selected=try SleepTopologyFixtures.select(source),prefix=source.session.snapshot(),solver=SleepTopologyFaultSolver(.unknown)
        let equation=try SleepTopologyFixtures.equation(selected.transition.release.target,target:true,solver:solver)
        var work=try SleepTopologyFixtures.work(operations:0)
        #expect(throws:TopologyReleaseFailure.self) {
            try ReferenceSleepTopologyTransitionPreparer().prepare(source:prefix,sourceConfiguration:source.session.configuration,
                retirement:selected.retirement,transition:selected.transition,history:source.history,observation:.explicit(selected.transition.release),ruleID:1,
                dispositions:[.appendHistory,.retireSleep,.initializeGlobalIntegration(retiredID:source.owner.continuation.schema.id)],
                targetConfiguration:selected.prepared.configuration,equations:equation,continuation:selected.continuation,validationBudget:work.budget,cancellation:nil,work:&work)
        }
        #expect(solver.invocationCount() == 0);#expect(source.session.snapshot() == prefix)
    }
}
