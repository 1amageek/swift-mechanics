import SwiftMechanics
import Testing
import Foundation

@Suite(.timeLimit(.minutes(1))) struct PrescribedRootEvolutionTests {
    @Test func rootOnlyPlanarAndSpatialKeepFullPhysicalForceEnergyAndExactCanonicalEndpoint() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            for planar in [true,false] {
                let fixture=try PrescribedRootEvolutionFixture(planar:planar),equation=try fixture.equation()
                let (session,continuation)=try fixture.session(equation);defer { _=session.shutdown() }
                let codec=NativeRuntimeCheckpointCodec(),saved=try session.checkpoint(codec:codec)
                let evolution:any ProjectedMechanismEvolving=ProjectedNonlinearMechanismEvolution()
                let final=try evolution.advance(session,equations:equation,continuation:continuation,to:0.4).accepted
                let state=final.checkpoint.physical,base=try fixture.sample(0.4),oracle=PrescribedRootOracle(planar:planar,time:0.4)
                #expect(state.q == base.q && state.v == base.v && state.acceleration == base.a)
                #expect(state.prescribedAnchors.isEmpty)
                let capture=NonlinearTestCapture()
                _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    var work=NumericalWork(budget:equation.publicationBudget)
                    capture.store(try equation.consistent(time:state.time,point:state.q+state.v,work:&work,control:control));_ = try trial.nextRandom();return .reject
                }
                let result=try #require(capture.read()),partition=try #require(result.partitionedPower),energy=try #require(result.mechanicalEnergy)
                #expect(result.acceleration.rank.rank == base.v.count && result.acceleration.rank.reactionNullity == 0)
                #expect(partition.knownCoordinates == Array(base.v.indices));#expect(partition.dynamicCoordinatePower == 0)
                #expect(abs(partition.anchorPrescribedPower) < 1e-10 && partition.drivePower == 0 && partition.geometricReactionPower == 0)
                for i in oracle.effort.indices {
                    #expect(abs(partition.rootActuationEffort[i]-oracle.effort[i]) < 1e-8)
                    #expect(abs(result.acceleration.generalizedReaction[i]-oracle.effort[i]) < 1e-8)
                }
                #expect(abs(energy.kineticEnergy-oracle.kinetic) < 1e-9)
                #expect(abs(energy.kineticEnergyRate-oracle.power) < 1e-8)
                #expect(abs(partition.knownCoordinatePower-oracle.power) < 1e-8)
                #expect(abs(partition.rootActuationPower-oracle.power) < 1e-8)
                // Simpson integrates the independent actuator power, not an energy diagnostic.
                let h=0.4/100,initial=PrescribedRootOracle(planar:planar,time:0).kinetic
                var workIntegral=0.0
                for i in 0...100 { workIntegral+=(i == 0 || i == 100 ? 1.0 : (i%2 == 0 ? 2 : 4))*PrescribedRootOracle(planar:planar,time:Double(i)*h).power*h/3 }
                #expect(abs(oracle.kinetic-initial-workIntegral) < 1e-9)
                #expect(session.snapshot() == final)
                let (fresh,freshContinuation)=try fixture.session(equation);defer { _=fresh.shutdown() }
                _=try fresh.restart(saved,codec:codec)
                let replay=try evolution.advance(fresh,equations:equation,continuation:freshContinuation,to:0.4).accepted
                #expect(replay == final);#expect(try fresh.checkpoint(codec:codec) == session.checkpoint(codec:codec))
                let history=try continuation.associatedHistory(final.checkpoint.contributors[0],physical:state,equations:equation)
                #expect(history.acceptedPoint == state.q+state.v && history.acceptedTime == 0.4)
            }
        }
    }
    @Test func rootWithCoupledPlanarAndSpatialDescendantsSharesTorqueAndPinsKnownMotion() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            for planar in [true,false] {
                let fixture=try PrescribedRootEvolutionFixture(planar:planar,descendants:true),equation=try fixture.equation()
                let (session,continuation)=try fixture.session(equation,step:0.02);defer { _=session.shutdown() }
                let final=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.4).accepted
                let state=final.checkpoint.physical,k=fixture.program.layout.velocityCount,p=fixture.program.layout.positionCount,base=try fixture.sample(0.4)
                #expect(Array(state.q[..<p]) == base.q && Array(state.v[..<k]) == base.v && Array(state.acceleration[..<k]) == base.a)
                for entry in fixture.model.tree.layout.joints {
                    #expect(abs(state.q[entry.positions.start]-(0.3+0.1*0.4-0.05*0.4*0.4)) < 1e-8)
                    #expect(abs(state.v[entry.velocities.start]-0.06) < 1e-8)
                    #expect(abs(state.acceleration[entry.velocities.start]+0.1) < 1e-8)
                }
                let capture=NonlinearTestCapture()
                _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    var work=NumericalWork(budget:equation.publicationBudget)
                    capture.store(try equation.consistent(time:state.time,point:state.q+state.v,work:&work,control:control));return .reject
                }
                let result=try #require(capture.read()),power=try #require(result.partitionedPower)
                #expect(result.acceleration.rank.rank == k+1 && result.acceleration.rank.reactionNullity == 1)
                #expect(abs(power.rootActuationEffort[k-1]-1.6) < 1e-8)
                #expect(abs(power.geometricReaction[fixture.first]+0.6) < 1e-8)
                #expect(abs(power.geometricReaction[fixture.second]-0.6) < 1e-8)
                #expect(abs(power.geometricReactionPower) < 1e-8)
                let vx=0.4+0.3*0.4,vy = -0.2+0.2*0.4,vz=planar ? 0.0 : 0.1-0.1*0.4,w=0.32
                let kinetic=2*(vx*vx+vy*vy+vz*vz)+w*w+2.5*(w+0.06)*(w+0.06)
                #expect(abs(result.kineticEnergy-kinetic) < 1e-8)
                let expectedPower=4*(vx*0.3+vy*0.2+(planar ? 0 : vz*(-0.1)))+1.6*w+0.06
                #expect(abs(power.energy.kineticEnergyRate-expectedPower) < 1e-8)
                #expect(abs(power.rootActuationPower+power.drivePower-expectedPower) < 1e-8)
                let initial=2*(0.4*0.4+0.2*0.2+(planar ? 0 : 0.1*0.1))+0.2*0.2+2.5*0.3*0.3
                let translationWork=2*(vx*vx+vy*vy+vz*vz-0.4*0.4-0.2*0.2-(planar ? 0 : 0.1*0.1))
                let rootAngularWork=1.6*(0.2*0.4+0.15*0.4*0.4),motorWork=0.1*0.4-0.05*0.4*0.4
                #expect(abs(result.kineticEnergy-initial-translationWork-rootAngularWork-motorWork) < 1e-8)
                let snapshot=try fixture.model.evaluate(fixture.model.makeState(state))
                let a=try snapshot.body(GeometricEvolutionFixtures.id(.body,"a")).motion,b=try snapshot.body(GeometricEvolutionFixtures.id(.body,"b")).motion
                let x=try a.pose.rotation.rotating(.unitX),y=try b.pose.rotation.rotating(.unitX)
                let dx=try a.velocity.angular.cross(x),dy=try b.velocity.angular.cross(y)
                let ddx=try a.acceleration.angular.cross(x).adding(a.velocity.angular.cross(dx)),ddy=try b.acceleration.angular.cross(y).adding(b.velocity.angular.cross(dy))
                #expect(try x.cross(y).magnitude() < 1e-9 && dx.subtracting(dy).magnitude() < 1e-9 && ddx.subtracting(ddy).magnitude() < 1e-8)
                #expect(try ddx.magnitude() > 0.1)
                let coarse=final
                let (refined,refinedContinuation)=try fixture.session(equation,step:0.01);defer { _=refined.shutdown() }
                let fine=try ProjectedNonlinearMechanismEvolution().advance(refined,equations:equation,continuation:refinedContinuation,to:0.4).accepted
                for i in state.q.indices { #expect(abs(coarse.checkpoint.physical.q[i]-fine.checkpoint.physical.q[i]) < 1e-9) }
            }
        }
    }
}
