import SwiftMechanics
import Testing

@Suite struct NonlinearSourceBindingTests {
    @Test(.timeLimit(.minutes(1))) func actualKernelDifferentPoseInertiaAndLoadAreRejected() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try NonlinearMechanismFixtures.model()
            for change in [WrongSourceKernel.Change.pose,.inertia,.load] {
                let equation=try NonlinearMechanismFixtures.equation(model,kernel:WrongSourceKernel(model:model,change:change))
                let (session,continuation)=try NonlinearMechanismFixtures.session(equation);defer { _=session.shutdown() }
                let prefix=session.snapshot()
                do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.02);Issue.record("Different dynamics physical source accepted") }
                catch {
                    #expect(error.cause.code == .invalidState)
                    #expect(error.cause.message == "Rigid supplier result source differs.")
                    #expect(error.lastAccepted == prefix);#expect(error.work.supplierArithmeticCharged > 0)
                }
                #expect(session.snapshot() == prefix)
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func actualSolverDifferentQuaternionSourceCannotInjectCoordinateRate() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try NonlinearMechanismFixtures.model(q:[1,0,0,0],v:[0,0,1],spherical:true)
            let equation=try NonlinearMechanismFixtures.quaternionEquation(model,solver:WrongSourceMechanismSolver(model:model))
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation);defer { _=session.shutdown() }
            let prefix=session.snapshot()
            do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.02);Issue.record("Different acceleration physical source accepted") }
            catch {
                #expect(error.cause.code == .invalidState)
                #expect(error.cause.message == "Mechanism supplier source/result differs.")
                #expect(error.lastAccepted == prefix);#expect(error.work.supplierArithmeticCharged > 0)
            }
            #expect(session.snapshot() == prefix)
        }
    }
}
