import Foundation
import SwiftMechanics
import Testing

@Suite struct MovingBaseEvolutionTests {
    @Test(.timeLimit(.minutes(1))) func actualCoupledLoopForcePowerAndExactRestart() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try MovingBaseFixture(),equation=try fixture.equation()
            let (session,continuation)=try fixture.session(equation);defer { _=session.shutdown() }
            let evolution:any ProjectedMechanismEvolving=ProjectedNonlinearMechanismEvolution()
            _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.5)
            let codec=NativeRuntimeCheckpointCodec(),saved=try session.checkpoint(codec:codec)
            let final=try evolution.advance(session,equations:equation,continuation:continuation,to:2).accepted
            let state=final.checkpoint.physical,t=state.time,v=state.v[fixture.first]
            #expect(abs(state.q[fixture.first]-(0.3+0.1*t+0.1*t*t)) < 1e-8)
            #expect(abs(v-(0.1+0.2*t)) < 1e-8)
            #expect(abs(state.q[fixture.first]-state.q[fixture.second]) < 1e-9)
            #expect(abs(state.v[fixture.first]-state.v[fixture.second]) < 1e-9)
            #expect(state.acceleration.allSatisfy { abs($0-0.2) < 1e-8 })
            let capture=NonlinearTestCapture()
            _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                var work=NumericalWork(budget:equation.publicationBudget)
                capture.store(try equation.consistent(time:t,point:state.q+state.v,work:&work,control:control));_ = try trial.nextRandom();return .reject
            }
            let result=try #require(capture.read()),energy=try #require(result.mechanicalEnergy)
            #expect(abs(result.kineticEnergy-fixture.kinetic(time:t,velocity:v)) < 1e-9)
            #expect(abs(energy.requiredVirtualPower-0.8*v) < 1e-9)
            #expect(abs(energy.requiredPrescribedPower-fixture.prescribedPower(time:t,torque:0.8)) < 1e-9)
            #expect(abs(energy.kineticEnergyRate-energy.requiredVirtualPower-energy.requiredPrescribedPower) < 1e-10)
            let virtualWork=0.8*(state.q[fixture.first]-0.3)
            let vx=0.6+0.3*t,vy=0.1-0.1*t,px=0.2+0.6*t+0.15*t*t,py = -0.1+0.1*t-0.05*t*t,w=0.4+0.2*t
            let prescribedWork=1.5*(vx*vx+vy*vy-0.6*0.6-0.1*0.1)+(0.2+0.8)*(0.4*t+0.1*t*t)
            #expect(abs(result.kineticEnergy-fixture.kinetic(time:0,velocity:0.1)-virtualWork-prescribedWork) < 1e-8)
            #expect(abs(energy.linearMomentum.x-3*vx) < 1e-10);#expect(abs(energy.linearMomentum.y-3*vy) < 1e-10)
            #expect(abs(energy.angularMomentum.z-(3*w+2*v+3*(px*vy-py*vx))) < 1e-9)
            #expect(abs(result.acceleration.generalizedReaction[fixture.first]+0.4) < 1e-9)
            #expect(abs(result.acceleration.generalizedReaction[fixture.second]-0.4) < 1e-9)
            #expect(result.acceleration.rank.rank == 1);#expect(result.acceleration.rank.reactionNullity == 1)
            #expect(session.snapshot() == final)
            // The energy oracle includes imposed translation, imposed spin, and their cross term with v.
            #expect(abs(result.kineticEnergy-v*v) > 1)
            _=try session.restart(saved,codec:codec)
            let replay=try evolution.advance(session,equations:equation,continuation:continuation,to:2).accepted
            #expect(replay == final)
            let (fresh,freshContinuation)=try fixture.session(equation);defer { _=fresh.shutdown() }
            _=try fresh.restart(saved,codec:codec)
            let cold=try evolution.advance(fresh,equations:equation,continuation:freshContinuation,to:2).accepted
            #expect(cold == final)
            #expect(try session.checkpoint(codec:codec) == fresh.checkpoint(codec:codec))
            let snapshot=try fixture.model.evaluate(fixture.model.makeState(state))
            let a=try snapshot.body(GeometricEvolutionFixtures.id(.body,"a")).motion,b=try snapshot.body(GeometricEvolutionFixtures.id(.body,"b")).motion
            let angle=0.4+0.4*t+0.1*t*t+state.q[fixture.first],omega=0.4+0.2*t+v,alpha=0.4
            let axis=try a.pose.rotation.rotating(.unitX),rate=try a.velocity.angular.cross(axis)
            let second=try a.acceleration.angular.cross(axis).adding(a.velocity.angular.cross(rate))
            #expect(abs(axis.x-cos(angle)) < 1e-10);#expect(abs(axis.y-sin(angle)) < 1e-10)
            #expect(abs(rate.x+omega*sin(angle)) < 1e-9);#expect(abs(rate.y-omega*cos(angle)) < 1e-9)
            #expect(abs(second.x+alpha*sin(angle)+omega*omega*cos(angle)) < 1e-9)
            #expect(abs(second.y-alpha*cos(angle)+omega*omega*sin(angle)) < 1e-9)
            #expect(try a.pose.translation.subtracting(b.pose.translation).magnitude() < 1e-10)
            #expect(try a.velocity.angular.subtracting(b.velocity.angular).magnitude() < 1e-9)
            #expect(try a.acceleration.angular.subtracting(b.acceleration.angular).magnitude() < 1e-9)
        }
    }
    @Test(.timeLimit(.minutes(1))) func movingBaseMixedQuaternionStagesKeepFullOriginalAxisAndPower() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try MovingBaseFixture(spherical:true),equation=try fixture.equation()
            let (session,continuation)=try fixture.session(equation,step:0.02);defer { _=session.shutdown() }
            let state=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.2).accepted.checkpoint.physical
            #expect(state.q.count == 8);#expect(state.v.count == 6)
            let expected=0.3+0.1*0.2+0.1*0.2*0.2
            for start in [fixture.first,fixture.second] {
                #expect(abs(state.q[start]-cos(expected/2)) < 1e-8)
                #expect(abs(state.q[start+3]-sin(expected/2)) < 1e-8)
                #expect(abs(state.q[start..<(start+4)].reduce(0) { $0+$1*$1 }-1) < 1e-10)
            }
            #expect(abs(state.v[fixture.firstVelocity+2]-0.14) < 1e-8)
            #expect(abs(state.acceleration[fixture.firstVelocity+2]-0.2) < 1e-8)
            let snapshot=try fixture.model.evaluate(fixture.model.makeState(state)),a=try snapshot.body(GeometricEvolutionFixtures.id(.body,"a")).motion,b=try snapshot.body(GeometricEvolutionFixtures.id(.body,"b")).motion
            let x=try a.pose.rotation.rotating(.unitX),y=try b.pose.rotation.rotating(.unitX)
            let dx=try a.velocity.angular.cross(x),dy=try b.velocity.angular.cross(y)
            let ddx=try a.acceleration.angular.cross(x).adding(a.velocity.angular.cross(dx)),ddy=try b.acceleration.angular.cross(y).adding(b.velocity.angular.cross(dy))
            #expect(try x.cross(y).magnitude() < 1e-9);#expect(try dx.subtracting(dy).magnitude() < 1e-9)
            #expect(try ddx.subtracting(ddy).magnitude() < 1e-8);#expect(try ddx.magnitude() > 0.4)
            let capture=NonlinearTestCapture()
            _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                var work=NumericalWork(budget:equation.publicationBudget)
                capture.store(try equation.consistent(time:state.time,point:state.q+state.v,work:&work,control:control));return .reject
            }
            let result=try #require(capture.read()),energy=try #require(result.mechanicalEnergy)
            #expect(abs(energy.kineticEnergy-fixture.kinetic(time:0.2,velocity:0.14)) < 1e-8)
            #expect(abs(energy.requiredPrescribedPower-fixture.prescribedPower(time:0.2,torque:0.8)) < 1e-8)
        }
    }
    @Test(.timeLimit(.minutes(1))) func samplePreservingAssemblyUsesPhysicalTimeWithoutAdvancingLaw() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try MovingBaseFixture(),initial=fixture.model.descriptor.initialState
            var q=initial.q;q[fixture.second]+=0.05
            let perturbed=try KinematicState(revision:1,time:0,q:q,v:initial.v,acceleration:initial.acceleration,prescribedAnchors:initial.prescribedAnchors)
            var work=try GeometricEvolutionFixtures.work()
            let result=try TangentManifoldAssembler().assemble(fixture.geometry,initial:perturbed,policy:GeometricEvolutionFixtures.policy(2),work:&work)
            #expect(abs(result.state.q[fixture.first]-result.state.q[fixture.second]) < 1e-9)
            #expect(result.state.prescribedAnchors == initial.prescribedAnchors);#expect(result.state.time == 0)
            #expect(result.pathCorrection > 0);#expect(result.rank.rank == 1)
        }
    }
}
