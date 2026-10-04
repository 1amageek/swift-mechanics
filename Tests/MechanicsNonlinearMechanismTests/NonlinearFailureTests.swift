import SwiftMechanics
import Testing

@Suite struct NonlinearFailureTests {
    @Test(.timeLimit(.minutes(1))) func lateSupplierResetOnSuccessAndFailurePreservesAcceptedPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            for fails in [false,true] {
                let equation=try NonlinearMechanismFixtures.equation(NonlinearMechanismFixtures.model(),evaluator:NonlinearLedgerSupplier(fails:fails))
                let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.05);defer { _=session.shutdown() }
                let evolution=ProjectedNonlinearMechanismEvolution()
                let prefix=try evolution.advance(session,equations:equation,continuation:continuation,to:0.05).accepted
                do throws(NonlinearMechanismFailure) { _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.1);Issue.record("Ledger reset accepted") }
                catch {
                    #expect(error.lastAccepted == prefix)
                    #expect(error.work.failedSupplierWorkUnavailable)
                    #expect(error.work.supplierArithmeticCharged > 0)
                    #expect(error.cause.code == .invalidOwnerAccess)
                }
                #expect(session.snapshot() == prefix)
                _=try continuation.associatedHistory(try #require(prefix.checkpoint.contributors.first),physical:prefix.checkpoint.physical,equations:equation)
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func lateSupplierCancellationPreservesKnownWorkWithoutRetry() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let equation=try NonlinearMechanismFixtures.equation(NonlinearMechanismFixtures.model(),evaluator:NonlinearLedgerSupplier(fails:true,resets:false))
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.05);defer { _=session.shutdown() }
            let evolution=ProjectedNonlinearMechanismEvolution()
            let prefix=try evolution.advance(session,equations:equation,continuation:continuation,to:0.05).accepted
            do throws(NonlinearMechanismFailure) { _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.1);Issue.record("Cancelled supplier accepted") }
            catch {
                #expect(error.lastAccepted == prefix);#expect(error.cause.code == .cancelled)
                #expect(!error.work.failedSupplierWorkUnavailable);#expect(error.work.supplierArithmeticCharged > 0)
                #expect(error.rejectedTrials == 0)
            }
            #expect(session.snapshot() == prefix)
        }
    }
    @Test(.timeLimit(.minutes(1))) func positionIterationExhaustionCannotPublish() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let base=try NonlinearMechanismFixtures.equation(NonlinearMechanismFixtures.model())
            let projection=try NonlinearMechanismProjectionPolicy(position:base.projection.position,maximumIterations:1,maximumCorrection:0.5)
            let equation=try NonlinearMechanismEquation(identity:"one-iteration",model:base.model,constraints:base.constraints,velocityLayout:base.velocityLayout,
                drive:base.drive,policy:base.policy,projection:projection,admission:NonlinearMechanismFixtures.admission(),maximumIdentityBytes:8192)
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.2);defer { _=session.shutdown() }
            let prefix=session.snapshot()
            do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.2);Issue.record("Insufficient projection iterations accepted") }
            catch { #expect(error.lastAccepted == prefix);#expect(error.work.supplierArithmeticCharged > 0) }
            #expect(session.snapshot() == prefix)
        }
    }
}
