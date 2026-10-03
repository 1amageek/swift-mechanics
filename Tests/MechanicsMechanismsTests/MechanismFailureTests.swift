import Testing
import MechanicsDynamics
import MechanicsMechanisms
import MechanicsIntegration

@Suite struct MechanismFailureTests {
    @Test func supplierActualWorkResetStopsAndPreservesPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(),system=try MechanismFixtures.system(model),sample=try MechanismFixtures.sample(),policy=try MechanismFixtures.policy()
            var w=try MechanismFixtures.work(),d=try MechanismFixtures.work(),r=try MechanismFixtures.work(),l=try MechanismFixtures.work()
            let solver=MassWeightedMechanismSolver(dynamics:ResettingDynamicsProvider())
            do throws(MechanismError) { _=try solver.acceleration(system,sample:sample,drive:[6,0],policy:policy,work:&w,dynamicsWork:&d,rankWork:&r,linearWork:&l);Issue.record("Replaced dynamics work accepted.") }
            catch { if case .supplierLedgerReplaced=error { #expect(error.failedSupplierWorkUnavailable) } else { Issue.record("Expected explicit work-authority failure.") } }
            #expect(d.operations == 1);#expect(r.operations == 0 && l.operations == 0)
            let equation=try AffineMechanismEquation(identity:"reset-test",model:model,constraints:MechanismFixtures.equations(),drive:[6,0],policy:policy,
                admission:MechanismFixtures.admission(),maximumIdentityBytes:1024,solver:solver)
            let (session,continuation)=try MechanismFixtures.session(model,equation:equation);defer { _=session.shutdown() };let prefix=session.snapshot()
            do throws(IntegrationFailure) { _=try ReferenceExplicitIntegrator().advance(session,model:model,equations:equation,continuation:continuation,to:0.1);Issue.record("Failed supplier evolution accepted.") }
            catch { #expect(error.lastAccepted == prefix);#expect(error.acceptedSteps == 0);#expect(error.rejectedTrials == 0);#expect(error.work.failedSupplierWorkUnavailable) }
            #expect(session.snapshot() == prefix)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func reusedHumanIdentityCannotHideChangedEquation() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(),policy=try MechanismFixtures.policy(),rows=try MechanismFixtures.equations(),admission=try MechanismFixtures.admission()
            let first=try AffineMechanismEquation(identity:"same",model:model,constraints:rows,drive:[6,0],policy:policy,admission:admission,maximumIdentityBytes:1024)
            let second=try AffineMechanismEquation(identity:"same",model:model,constraints:rows,drive:[7,0],policy:policy,admission:admission,maximumIdentityBytes:1024)
            #expect(first.descriptor != second.descriptor)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
