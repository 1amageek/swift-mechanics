import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ToothFailureTests {
    @Test func originalGeometryAndDynamicsRejectDelegatedWrongPhysicalSource() throws {
        let model=try ToothFixtures.model(), state=try ToothFixtures.initial(model), policy=try ToothFixtures.policy()
        for service in [ReferenceToothContactEvolution(model:model,geometry:ToothWrongGeometry()),ReferenceToothContactEvolution(model:model,dynamics:ToothWrongDynamics())] {
            var work=try ToothFixtures.work()
            do throws(ToothContactError) { _=try service.step(accepted:state,timeStep:0.001,policy:policy,work:&work); Issue.record("Wrong original source accepted.") }
            catch { if case .invalidSupplierOutput=error {} else { Issue.record("Unexpected failure: \(error)") } }
            #expect(work.operations > 0 && work.supplierCalls > 0)
            #expect(state.physical.time == 0 && state.histories[0].sequence == 0)
        }
    }
    @Test func changedInertiaSameRevisionAndIncompleteCatalogCannotReplay() throws {
        let model=try ToothFixtures.model(), state=try ToothFixtures.initial(model), other=try ToothFixtures.model(inertia:2), policy=try ToothFixtures.policy()
        var work=try ToothFixtures.work()
        do throws(ToothContactError) { _=try ReferenceToothContactEvolution(model:other).step(accepted:state,timeStep:0.001,policy:policy,work:&work); Issue.record("Changed physical source accepted.") }
        catch { if case .staleSource=error {} else { Issue.record("Unexpected failure: \(error)") } }
        do { _=try ToothFixtures.model(mesh:2,missingPair:true); Issue.record("Missing real pair accepted.") }
        catch let error as ToothContactError { if case .invalidInput=error {} else { Issue.record("Unexpected failure: \(error)") } }
        #expect(state.physical.time == 0 && state.histories[0].sequence == 0)
    }
    @Test func explicitFidelityUnsupportedLawAndOperationalLimits() throws {
        let model=try ToothFixtures.model(), initial=try ToothFixtures.initial(model)
        do { _=try ToothFixtures.model(damping:1); Issue.record("Unqualified damping branch accepted.") }
        catch let error as ToothContactError { if case .unsupportedDomain=error {} else { Issue.record("Unexpected failure: \(error)") } }
        let policies=try [ToothFixtures.policy(spacing:0.01),ToothFixtures.policy(error:0.001),ToothFixtures.policy(cancelled:{true})]
        for policy in policies {
            var work=try ToothFixtures.work()
            do throws(ToothContactError) { _=try ReferenceToothContactEvolution(model:model).step(accepted:initial,timeStep:0.001,policy:policy,work:&work); Issue.record("Out of policy accepted.") }
            catch { switch error { case .capacityExceeded,.collision(.approximationExceeded),.cancelled: break; default: Issue.record("Unexpected failure: \(error)") } }
        }
        let policy=try ToothFixtures.policy()
        for workTemplate in try [ToothFixtures.work(operations:1),ToothFixtures.work(storage:1),ToothFixtures.work(calls:0)] {
            var work=workTemplate
            do throws(ToothContactError) { _=try ReferenceToothContactEvolution(model:model).step(accepted:initial,timeStep:0.001,policy:policy,work:&work); Issue.record("Capacity exceeded.") }
            catch { if case .capacityExceeded=error {} else { Issue.record("Unexpected failure: \(error)") } }
            #expect(work.operations <= work.budget.arithmeticOperations && work.supplierCalls <= work.maximumSupplierCalls)
        }
    }
    @Test func failedStepRollsBackAndAdvancePreservesActualAcceptedPrefix() throws {
        let model=try ToothFixtures.model(), initial=try ToothFixtures.initial(model), policy=try ToothFixtures.policy(maximumSteps:1)
        let service:any ToothContactEvolving=ReferenceToothContactEvolution(model:model)
        var work=try ToothFixtures.work()
        do throws(ToothContactFailure) { _=try service.advance(accepted:initial,to:0.002,timeStep:0.001,policy:policy,work:&work); Issue.record("Step cap ignored.") }
        catch {
            if case .capacityExceeded=error.cause {} else { Issue.record("Unexpected failure: \(error.cause)") }
            #expect(error.completedSteps == 1 && error.accepted.physical.time == 0.001)
            #expect(error.accepted.histories[0].sequence == 1 && error.work.operations == work.operations)
        }
        let tight=try ToothFixtures.policy(defect:0)
        work=try ToothFixtures.work()
        do throws(ToothContactError) { _=try service.step(accepted:initial,timeStep:0.01,policy:tight,work:&work); Issue.record("Finite-step defect was hidden.") }
        catch { if case .energyDefect=error {} else { Issue.record("Unexpected failure: \(error)") } }
        #expect(initial.physical.time == 0 && initial.histories[0].sequence == 0)
    }
    @Test(arguments:[0,1,2,3]) func supplierFailureResetAndLateCancellationKeepKnownPrefix(mode: Int) throws {
        if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, *) {
            let model=try ToothFixtures.model(), initial=try ToothFixtures.initial(model)
            let modes:[ToothLawFault.Mode]=[.fail,.reset,.cancelSuccess,.cancelThrow], supplier=ToothLawFault(modes[mode])
            let policy=try ToothFixtures.policy(cancelled:{supplier.cancelled})
            var work=try ToothFixtures.work()
            let service:any ToothContactEvolving=ReferenceToothContactEvolution(model:model,laws:supplier)
            do throws(ToothContactFailure) { _=try service.advance(accepted:initial,to:0.001,timeStep:0.001,policy:policy,work:&work); Issue.record("Fault supplier accepted.") }
            catch {
                switch mode {
                case 0: if case .contact(.invalidInput)=error.cause {} else { Issue.record("Unexpected failure: \(error.cause)") }
                case 1: if case .invalidSupplierLedger(let unavailable)=error.cause { #expect(unavailable) } else { Issue.record("Unexpected failure: \(error.cause)") }
                default: if case .cancelled=error.cause {} else { Issue.record("Unexpected failure: \(error.cause)") }
                }
                #expect(error.accepted.physical == initial.physical && error.accepted.histories == initial.histories && error.completedSteps == 0)
                if mode != 1 { #expect(error.work.operations >= supplier.prefix) }
                #expect(error.work.operations == work.operations && supplier.calls == 1)
            }
        }
    }
    @Test func taskCancellationAfterSupplierStillMergesPrefix() async throws {
        if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, *) {
            let model=try ToothFixtures.model(), initial=try ToothFixtures.initial(model), supplier=ToothLawFault(.taskCancel), policy=try ToothFixtures.policy()
            let job=Task { () throws -> (ToothContactFailure?,ToothContactWork) in
                var work=try ToothFixtures.work()
                do throws(ToothContactFailure) {
                    _=try ReferenceToothContactEvolution(model:model,laws:supplier).advance(accepted:initial,to:0.001,timeStep:0.001,policy:policy,work:&work)
                    return (nil,work)
                } catch { return (error,work) }
            }
            let (failure,work)=try await job.value
            guard let failure else { Issue.record("Task cancellation not reported."); return }
            if case .cancelled=failure.cause {} else { Issue.record("Unexpected failure: \(failure.cause)") }
            #expect(work.operations >= supplier.prefix && supplier.calls == 1)
            #expect(failure.accepted.physical == initial.physical && failure.accepted.histories == initial.histories)
        }
    }
}
