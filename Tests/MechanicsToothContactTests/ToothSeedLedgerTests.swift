@testable import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ToothSeedLedgerTests {
    @Test func resetNumericLedgerPreservesKnownOperationAndIterationSeeds() throws {
        let policy=try ToothFixtures.policy()
        var work=try ToothContactWork(budget:NumericalBudget(scalarStorage:1000,arithmeticOperations:100,iterations:10),maximumSupplierCalls:10)
        do throws(ToothContactError) {
            try ToothArithmetic.numeric(reserved:0,policy:policy,work:&work) { (local: inout NumericalWork) throws(DynamicsError) in
                local=NumericalWork(budget:local.budget)
            }
            Issue.record("Reset ledger accepted.")
        } catch { if case .invalidSupplierLedger(let unavailable)=error { #expect(unavailable) } else { Issue.record("Unexpected failure: \(error)") } }
        #expect(work.operations == 2 && work.iterations == 1 && work.supplierCalls == 1)
    }
    @Test func resetCollisionLedgerPreservesKnownOperationAndIterationSeeds() throws {
        let policy=try ToothFixtures.policy()
        var work=try ToothContactWork(budget:NumericalBudget(scalarStorage:1000,arithmeticOperations:100,iterations:10),maximumSupplierCalls:10)
        do throws(ToothContactError) {
            try ToothArithmetic.collision(reserved:0,policy:policy,work:&work) { (local: inout CollisionWork) throws(CollisionError) in
                local=CollisionWork(budget:local.budget)
            }
            Issue.record("Reset ledger accepted.")
        } catch { if case .invalidSupplierLedger(let unavailable)=error { #expect(unavailable) } else { Issue.record("Unexpected failure: \(error)") } }
        #expect(work.operations == 2 && work.iterations == 1 && work.supplierCalls == 1)
    }
    @Test func resetContactLedgerPreservesKnownOperationSeed() throws {
        let policy=try ToothFixtures.policy()
        var work=try ToothContactWork(budget:NumericalBudget(scalarStorage:1000,arithmeticOperations:100,iterations:10),maximumSupplierCalls:10)
        do throws(ToothContactError) {
            try ToothArithmetic.contact(reserved:0,policy:policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
                local=ContactWork(budget:local.budget)
            }
            Issue.record("Reset ledger accepted.")
        } catch { if case .invalidSupplierLedger(let unavailable)=error { #expect(unavailable) } else { Issue.record("Unexpected failure: \(error)") } }
        #expect(work.operations == 2 && work.iterations == 0 && work.supplierCalls == 1)
    }
    @Test(arguments:[true,false]) func partialIterationSeedFailurePreservesExecutedOperation(numeric: Bool) throws {
        let policy=try ToothFixtures.policy()
        var work=try ToothContactWork(budget:NumericalBudget(scalarStorage:1000,arithmeticOperations:100,iterations:0),maximumSupplierCalls:10)
        var called=false
        do throws(ToothContactError) {
            if numeric {
                try ToothArithmetic.numeric(reserved:0,policy:policy,work:&work) { (local: inout NumericalWork) throws(DynamicsError) in called=true }
            } else {
                try ToothArithmetic.collision(reserved:0,policy:policy,work:&work) { (local: inout CollisionWork) throws(CollisionError) in called=true }
            }
            Issue.record("Zero iteration allowance accepted.")
        } catch { switch error { case .numerical,.collision: break; default: Issue.record("Unexpected failure: \(error)") } }
        #expect(!called && work.operations == 2 && work.iterations == 0 && work.supplierCalls == 1)
    }
    @Test func assemblyPartialSeedFailureRetainsOnlyExecutedNumericalPrefix() throws {
        let model=try ToothFixtures.model(), policy=try ToothFixtures.policy()
        let snapshot=try TreeKinematicsEvaluator().evaluate(model.tree,
            state:KinematicState(revision:1,time:0,q:[0,0],v:[0,0],acceleration:[0,0]),policy:model.jointPolicy)
        let input=try RigidDynamicsInput(snapshot:snapshot,velocity:[0,0],inertias:model.inertias,gravity:nil)
        let physics=ToothContactPhysics(model:model,geometry:AnalyticCollisionQueries(),laws:CompliantContactEvaluator(),dynamics:DenseRigidDynamics())
        var work=try ToothContactWork(budget:NumericalBudget(scalarStorage:1000,arithmeticOperations:100,iterations:0),maximumSupplierCalls:10)
        do throws(ToothContactError) {
            _=try physics.assemble(input,policy:policy,reserved:0,work:&work)
            Issue.record("Zero assembly iteration allowance accepted.")
        } catch { if case .numerical=error {} else { Issue.record("Unexpected failure: \(error)") } }
        #expect(work.operations == 2 && work.iterations == 0 && work.supplierCalls == 1)
    }

    @Test(arguments:[true,false]) func validFullPrefixIsAbsorbedExactlyOnce(success: Bool) throws {
        let policy=try ToothFixtures.policy()
        var work=try ToothContactWork(budget:NumericalBudget(scalarStorage:1000,arithmeticOperations:5,iterations:2),maximumSupplierCalls:1)
        do throws(ToothContactError) {
            try ToothArithmetic.numeric(reserved:0,policy:policy,work:&work) { (local: inout NumericalWork) throws(DynamicsError) in
                do throws(NumericalError) { try local.chargeOperations(3); try local.advanceIteration() }
                catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
                if !success { throw .invalidInput }
            }
            #expect(success)
        } catch { if case .dynamics(.invalidInput)=error { #expect(!success) } else { Issue.record("Unexpected failure: \(error)") } }
        #expect(work.operations == 5 && work.iterations == 2 && work.supplierCalls == 1)
    }

}
