import Foundation
import SwiftMechanics
import Testing

@Suite struct NonlinearEvolutionTests {
    @Test(.timeLimit(.minutes(1))) func circleLongRunOriginalReactionAndReplay() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let equation=try NonlinearMechanismFixtures.equation(NonlinearMechanismFixtures.model(),redundant:true)
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.02);defer { _=session.shutdown() }
            let evolution=ProjectedNonlinearMechanismEvolution()
            _=try evolution.advance(session,equations:equation,continuation:continuation,to:5)
            let checkpoint=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            let result=try evolution.advance(session,equations:equation,continuation:continuation,to:20)
            let state=result.accepted.checkpoint.physical,q=state.q,v=state.v
            #expect(abs(q[0]*q[0]+q[1]*q[1]-1) < 1e-10)
            #expect(abs(q[0]*v[0]+q[1]*v[1]) < 1e-9)
            #expect(abs(v[0]*v[0]+v[1]*v[1]-1) < 2e-6)
            #expect(abs(q[0]-cos(20)) < 2e-5);#expect(abs(q[1]-sin(20)) < 2e-5)
            #expect(abs(state.acceleration[0]+q[0]) < 2e-6);#expect(abs(state.acceleration[1]+q[1]) < 2e-6)
            let history=try continuation.associatedHistory(try #require(result.accepted.checkpoint.contributors.first),physical:state,equations:equation)
            #expect(history.acceptedTime == 20);#expect(history.acceptedPoint == q+v)
            _=try session.restart(checkpoint,codec:NativeRuntimeCheckpointCodec())
            let replay=try evolution.advance(session,equations:equation,continuation:continuation,to:20)
            #expect(replay.accepted == result.accepted)
            #expect(result.work.supplierArithmeticCharged > 0)
        }
    }
    @Test(.timeLimit(.minutes(1))) func fourthOrderRefinementAgainstIndependentCircleSolution() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            var errors:[Double]=[]
            for step in [0.1,0.05,0.025] {
                let equation=try NonlinearMechanismFixtures.equation(NonlinearMechanismFixtures.model())
                let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:step);defer { _=session.shutdown() }
                let result=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:1)
                let q=result.accepted.checkpoint.physical.q
                errors.append((q[0]-cos(1))*(q[0]-cos(1))+(q[1]-sin(1))*(q[1]-sin(1)))
            }
            #expect(errors[0]/errors[1] > 100);#expect(errors[1]/errors[2] > 100)
        }
    }
    @Test(.timeLimit(.minutes(1))) func pendulumEnergyAndIndependentAcceleration() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let equation=try NonlinearMechanismFixtures.equation(NonlinearMechanismFixtures.model(q:[1,0],v:[0,0]),drive:[0,-9.81])
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.005);defer { _=session.shutdown() }
            let result=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:5)
            let s=result.accepted.checkpoint.physical,q=s.q,v=s.v,speed=v[0]*v[0]+v[1]*v[1]
            let radial = -speed+9.81*q[1]
            #expect(abs(s.acceleration[0]-radial*q[0]) < 1e-7)
            #expect(abs(s.acceleration[1]-(-9.81+radial*q[1])) < 1e-7)
            #expect(abs(0.5*speed+9.81*q[1]) < 1e-4)
            #expect(abs(q[0]*s.acceleration[0]+q[1]*s.acceleration[1]+speed) < 1e-7)
        }
    }
    @Test(.timeLimit(.minutes(1))) func quaternionManifoldUsesBodyAngularRateAndNorm() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let equation=try NonlinearMechanismFixtures.quaternionEquation(NonlinearMechanismFixtures.model(q:[1,0,0,0],v:[0,0,1],spherical:true))
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.02);defer { _=session.shutdown() }
            let result=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:4)
            let s=result.accepted.checkpoint.physical
            #expect(s.q.count == 4);#expect(s.v.count == 3)
            #expect(abs(s.q.reduce(0){$0+$1*$1}-1) < 1e-10)
            #expect(abs(s.q[0]-cos(2)) < 1e-6);#expect(abs(s.q[3]-sin(2)) < 1e-6)
            #expect(abs(s.v[2]-1) < 1e-9);#expect(abs(s.acceleration[2]) < 1e-9)
        }
    }
    @Test(.timeLimit(.minutes(1))) func adaptiveRejectionsAndInconsistentInitialRollback() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let equation=try NonlinearMechanismFixtures.equation(NonlinearMechanismFixtures.model())
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.2,adaptive:true);defer { _=session.shutdown() }
            let result=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.1)
            #expect(result.rejectedTrials > 0)
            let history=try continuation.associatedHistory(try #require(result.accepted.checkpoint.contributors.first),physical:result.accepted.checkpoint.physical,equations:equation)
            #expect(history.acceptedSteps == UInt64(result.acceptedSteps))
            for (q,v) in [([1.1,0],[0.0,1.0]),([1.0,0],[1.0,1.0])] {
                let invalid=try NonlinearMechanismFixtures.equation(NonlinearMechanismFixtures.model(q:q,v:v))
                let (bad,history)=try NonlinearMechanismFixtures.session(invalid);defer { _=bad.shutdown() }
                let before=bad.snapshot()
                do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(bad,equations:invalid,continuation:history,to:0.1);Issue.record("Inconsistent initial state accepted") }
                catch { #expect(error.lastAccepted == before) }
                #expect(bad.snapshot() == before)
            }
        }
    }
}
