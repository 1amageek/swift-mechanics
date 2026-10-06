import SwiftMechanics
import Testing

@Suite("Constrained impact supplier work and original acceptance")
struct ConstrainedImpactLedgerTests {
    @Test func genuineAssemblyFromAnotherSameStampPositionCannotReplaceOriginalSource() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(), rows = try ConstrainedImpactFixtures.constraints(input.model), token = HybridCancellation()
        let state = try KinematicState(revision:1,time:input.physical.state.time,q:[0.1,-0.1,0.5],v:input.physical.state.v,acceleration:[0,0,0])
        let alternate = try input.model.evaluate(input.model.makeState(state))
        let dynamics = try RigidDynamicsInput(snapshot:alternate,velocity:input.physical.state.v,inertias:input.inertias,gravity:nil)
        let supplier = ImpactFaultEquationSupplier(.falseResult,substitute:dynamics)
        var work = try ConstrainedImpactFixtures.numerical(), loads = try ConstrainedImpactFixtures.load(token)
        do {
            _ = try ReferenceConstrainedImpactPreparer(equations:supplier).prepare(input:input,constraints:rows,
                policy:ConstrainedImpactFixtures.policy(),admission:ConstrainedImpactFixtures.admission(token),loadWork:&loads,work:&work,cancellation:token)
            Issue.record("Genuine mass assembly from another same-stamp q was accepted.")
        } catch let error as ConstrainedImpactError { if case .sourceMismatch = error.reason {} else { Issue.record("Wrong actual source refusal.") } }
        #expect(supplier.callCount == 1); #expect(work.operations > 0)
        #expect(input.physical.state.q == [0,0,0.5])
    }
    @Test func internallyConsistentPredictionForAnotherLawCannotReplaceTheSelectedLaw() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let source = try ConstrainedImpactFixtures.prepared(ConstrainedImpactFixtures.input(restitution:1))
        let supplier = ImpactFaultContactSupplier(.falseResult,substitute:try ConstrainedImpactFixtures.law(0))
        var work = try ConstrainedImpactFixtures.numerical(), contact = try ConstrainedImpactFixtures.contact()
        do { _ = try ReferenceConstrainedNormalImpulseSolver(laws:supplier).solve(source,work:&work,contactWork:&contact,cancellation:HybridCancellation()); Issue.record("A consistent prediction for another law was accepted.") }
        catch let error as ConstrainedImpactError { if case .residualRejected = error.reason {} else { Issue.record("Wrong selected-law refusal.") } }
        #expect(supplier.callCount == 1); #expect(contact.operations > 1)
    }
    @Test(arguments:[ConstrainedImpactFault.resetSuccess,.resetFailure,.cancelled])
    func massLedgerResetPreservesKnownAdmissionAndNeverRetries(_ fault: ConstrainedImpactFault) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let source = try ConstrainedImpactFixtures.prepared(ConstrainedImpactFixtures.input()), supplier = ImpactFaultMassSupplier(fault)
        var work = try ConstrainedImpactFixtures.numerical(), contact = try ConstrainedImpactFixtures.contact()
        try work.chargeOperations(13); let known = work
        do { _ = try ReferenceConstrainedNormalImpulseSolver(mass:supplier).solve(source,work:&work,contactWork:&contact,cancellation:HybridCancellation()); Issue.record("Reset mass ledger was accepted.") }
        catch let error as ConstrainedImpactError {
            #expect(error.failedSupplierWorkUnavailable)
            if fault == .cancelled { if case .dynamics(.cancelled) = error.reason {} else { Issue.record("Original cancellation was lost.") } }
            else { if case .supplierLedgerFailure = error.reason {} else { Issue.record("Reset was not identified.") } }
            if fault == .resetFailure { if case .dynamics(.invalidInput)? = error.supplierFailure {} else { Issue.record("Original failed supplier cause was lost.") } }
        }
        #expect(work.operations == known.operations+1); #expect(work.budget == known.budget)
        #expect(supplier.callCount == 1); #expect(contact.operations == 0)
    }
    @Test(arguments:[ConstrainedImpactFault.resetSuccess,.resetFailure,.cancelled])
    func contactResetPreservesItsSeparateLedgerAndFailure(_ fault: ConstrainedImpactFault) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let source = try ConstrainedImpactFixtures.prepared(ConstrainedImpactFixtures.input()), supplier = ImpactFaultContactSupplier(fault)
        var work = try ConstrainedImpactFixtures.numerical(), contact = try ConstrainedImpactFixtures.contact()
        try contact.consume(operations:11,scalarStorage:3,records:1)
        do { _ = try ReferenceConstrainedNormalImpulseSolver(laws:supplier).solve(source,work:&work,contactWork:&contact,cancellation:HybridCancellation()); Issue.record("Reset contact ledger was accepted.") }
        catch let error as ConstrainedImpactError {
            #expect(error.failedSupplierWorkUnavailable)
            if fault == .cancelled { if case .contact(.cancelled) = error.reason {} else { Issue.record("Original contact cancellation was lost.") } }
            else { if case .supplierLedgerFailure = error.reason {} else { Issue.record("Contact reset was not identified.") } }
        }
        #expect(contact.operations == 12); #expect(contact.peakScalarStorage == 3)
        #expect(work.operations > 0); #expect(supplier.callCount == 1)
    }
    @Test(arguments:[false,true]) func assemblyResetCannotBeMaskedByLaterAdapterRowWork(_ resetLoads: Bool) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(), rows = try ConstrainedImpactFixtures.constraints(input.model), token = HybridCancellation()
        let supplier = ImpactFaultEquationSupplier(.resetSuccess,loadReset:resetLoads)
        var work = try ConstrainedImpactFixtures.numerical(), loads = try ConstrainedImpactFixtures.load(token)
        try work.chargeOperations(17); try loads.charge(19)
        do {
            _ = try ReferenceConstrainedImpactPreparer(equations:supplier).prepare(input:input,constraints:rows,
                policy:ConstrainedImpactFixtures.policy(),admission:ConstrainedImpactFixtures.admission(token),loadWork:&loads,work:&work,cancellation:token)
            Issue.record("Assembly reset was accepted after subsequent adapter work.")
        } catch let error as ConstrainedImpactError {
            if case .supplierLedgerFailure = error.reason {} else { Issue.record("Wrong assembly reset failure.") }
            #expect(error.failedSupplierWorkUnavailable)
        }
        #expect(work.operations >= 19); #expect(loads.consumed >= 21); #expect(supplier.callCount == 1)
    }
    @Test(arguments:[ConstrainedImpactFault.resetSuccess,.resetFailure,.falseResult])
    func evaluatorResetOrSourceSubstitutionCannotPublishPreparation(_ fault: ConstrainedImpactFault) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(), rows = try ConstrainedImpactFixtures.constraints(input.model), token = HybridCancellation()
        let supplier = ImpactFaultEvaluator(fault)
        var work = try ConstrainedImpactFixtures.numerical(), loads = try ConstrainedImpactFixtures.load(token)
        do {
            _ = try ReferenceConstrainedImpactPreparer(evaluator:supplier).prepare(input:input,constraints:rows,
                policy:ConstrainedImpactFixtures.policy(),admission:ConstrainedImpactFixtures.admission(token),loadWork:&loads,work:&work,cancellation:token)
            Issue.record("Invalid evaluator authority was admitted.")
        } catch let error as ConstrainedImpactError {
            if fault == .falseResult { if case .sourceMismatch = error.reason {} else { Issue.record("Changed original Jacobian was not rejected.") } }
            else { if case .supplierLedgerFailure = error.reason {} else { Issue.record("Evaluator reset was not identified.") }; #expect(error.failedSupplierWorkUnavailable) }
        }
        #expect(work.operations > 0); #expect(supplier.callCount == 1)
    }
    @Test func opaqueLinearFailureRetainsTheKnownMassPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let source = try ConstrainedImpactFixtures.prepared(ConstrainedImpactFixtures.input()), supplier = ImpactFailingLinearSupplier()
        var work = try ConstrainedImpactFixtures.numerical(), contact = try ConstrainedImpactFixtures.contact()
        do { _ = try ReferenceConstrainedNormalImpulseSolver(linear:supplier).solve(source,work:&work,contactWork:&contact,cancellation:HybridCancellation()); Issue.record("Failed linear solve was accepted.") }
        catch let error as ConstrainedImpactError {
            if case .numerical(.singular(rank:0,pivot:0)) = error.reason {} else { Issue.record("Original linear failure was lost.") }
            #expect(error.failedSupplierWorkUnavailable)
        }
        #expect(work.operations > 1); #expect(work.iterations > 0); #expect(supplier.callCount == 1); #expect(contact.operations == 0)
    }
    @Test func originalMassActionIsRecheckedAndSupplierCapsPreventCall() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let source = try ConstrainedImpactFixtures.prepared(ConstrainedImpactFixtures.input())
        var work = try ConstrainedImpactFixtures.numerical(), contact = try ConstrainedImpactFixtures.contact()
        do { _ = try ReferenceConstrainedNormalImpulseSolver(equations:ImpactFaultEquationSupplier(.falseResult)).solve(source,
            work:&work,contactWork:&contact,cancellation:HybridCancellation()); Issue.record("False original mass acceptance succeeded.") }
        catch let error as ConstrainedImpactError { if case .residualRejected = error.reason {} else { Issue.record("Wrong original momentum failure.") } }
        let mass = ImpactFaultMassSupplier(.failure)
        work = try ConstrainedImpactFixtures.numerical(operations:0)
        do { _ = try ReferenceConstrainedNormalImpulseSolver(mass:mass).solve(source,work:&work,contactWork:&contact,cancellation:HybridCancellation()); Issue.record("Mass callback ran without admission work.") }
        catch let error as ConstrainedImpactError { if case .numerical(.resourceLimit) = error.reason {} else { Issue.record("Wrong work preflight refusal.") } }
        #expect(mass.callCount == 0)
        let laws = ImpactFaultContactSupplier(.failure)
        work = try ConstrainedImpactFixtures.numerical()
        contact = ContactWork(budget:try ContactBudget(operations:0,scalarStorage:1000,records:1))
        do { _ = try ReferenceConstrainedNormalImpulseSolver(laws:laws).solve(source,work:&work,contactWork:&contact,cancellation:HybridCancellation()); Issue.record("Contact callback ran without admission work.") }
        catch let error as ConstrainedImpactError { if case .contact(.resourceLimit) = error.reason {} else { Issue.record("Wrong contact work refusal.") } }
        #expect(laws.callCount == 0)
    }
}
