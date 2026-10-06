import SwiftMechanics
import Testing
import Foundation

@Suite(.timeLimit(.minutes(3))) struct TrajectoryEvolutionTests {
    @Test func actualHarmonicAndPiecewiseRootsRetainOriginalEffortEnergyPowerAndWork() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            for planar in [true,false] { for piecewise in [true,false] {
                let fixture=try TrajectoryEvolutionFixtures(planar:planar,piecewise:piecewise),equation=try fixture.equation()
                let (session,continuation)=try fixture.session(equation);defer { _=session.shutdown() }
                let accepted=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:1.4).accepted
                let state=accepted.checkpoint.physical,base=try fixture.sample(1.4)
                #expect(state.q == base.q && state.v == base.v && state.acceleration == base.a && state.prescribedAnchors.isEmpty)
                let oracle=TrajectoryMotionOracle(time:1.4,planar:planar,piecewise:piecewise),expected=oracle.physical(planar:planar)
                let capture=NonlinearTestCapture()
                _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    var work=NumericalWork(budget:equation.publicationBudget)
                    capture.store(try equation.consistent(time:state.time,point:state.q+state.v,work:&work,control:control));_ = try trial.nextRandom();return .reject
                }
                let result=try #require(capture.read()),partition=try #require(result.partitionedPower),energy=try #require(result.mechanicalEnergy)
                for i in expected.effort.indices { #expect(abs(partition.rootActuationEffort[i]-expected.effort[i]) < 1e-8) }
                #expect(abs(energy.kineticEnergy-expected.kinetic) < 1e-9)
                #expect(abs(energy.kineticEnergyRate-expected.power) < 1e-8)
                #expect(abs(partition.rootActuationPower-expected.power) < 1e-8)
                #expect(partition.drivePower == 0 && partition.anchorPrescribedPower == 0 && partition.dynamicCoordinatePower == 0)
                var integral=0.0
                // Split independent Simpson quadrature at the real C2 knot, without consuming returned energy diagnostics.
                for interval in [(0.0,1.0),(1.0,1.4)] {
                    let h=(interval.1-interval.0)/200
                    for i in 0...200 {
                        let power=TrajectoryMotionOracle(time:interval.0+Double(i)*h,planar:planar,piecewise:piecewise).physical(planar:planar).power
                        integral+=(i == 0 || i == 200 ? 1.0 : (i%2 == 0 ? 2 : 4))*power*h/3
                    }
                }
                let initial=TrajectoryMotionOracle(time:0,planar:planar,piecewise:piecewise).physical(planar:planar).kinetic
                #expect(abs(expected.kinetic-initial-integral) < 1e-8)
                let history=try continuation.associatedHistory(accepted.checkpoint.contributors[0],physical:state,equations:equation)
                #expect(history.acceptedTime.bitPattern == state.time.bitPattern && history.acceptedPoint == state.q+state.v)
                #expect(session.snapshot() == accepted)
            } }
        }
    }
    @Test func genuineDescendantLoopBalancesRootMotorEffortAndOriginalPhysicalAxes() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            for planar in [true,false] { for piecewise in [true,false] {
                let fixture=try TrajectoryEvolutionFixtures(planar:planar,piecewise:piecewise,descendants:true),equation=try fixture.equation()
                let (session,continuation)=try fixture.session(equation,step:0.02);defer { _=session.shutdown() }
                let t=1.2,accepted=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:t).accepted,state=accepted.checkpoint.physical
                let jet=TrajectoryMotionOracle(time:t,planar:planar,piecewise:piecewise),q=0.3+0.3*t+0.1*t*t-jet.angle,v=0.3+0.2*t-jet.rate,a=0.2-jet.second
                for entry in fixture.model.tree.layout.joints {
                    #expect(abs(state.q[entry.positions.start]-q) < 2e-8)
                    #expect(abs(state.v[entry.velocities.start]-v) < 2e-8)
                    #expect(abs(state.acceleration[entry.velocities.start]-a) < 1e-8)
                }
                let capture=NonlinearTestCapture()
                _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    var work=NumericalWork(budget:equation.publicationBudget)
                    capture.store(try equation.consistent(time:t,point:state.q+state.v,work:&work,control:control));return .reject
                }
                let result=try #require(capture.read()),power=try #require(result.partitionedPower),k=fixture.program.layout.velocityCount
                let translation=zip(jet.velocity,jet.acceleration).reduce(0.0) { $0+$1.0*$1.1 }
                let kinetic=2*jet.velocity.reduce(0) { $0+$1*$1 }+jet.rate*jet.rate+2.5*pow(jet.rate+v,2)
                let expectedPower=4*translation+(2*jet.second+1)*jet.rate+v
                #expect(abs(power.rootActuationEffort[k-1]-(2*jet.second+1)) < 1e-8)
                #expect(abs(result.kineticEnergy-kinetic) < 2e-8)
                #expect(abs(power.energy.kineticEnergyRate-expectedPower) < 2e-8)
                #expect(abs(power.rootActuationPower+power.drivePower-expectedPower) < 2e-8)
                #expect(abs(power.geometricReactionPower) < 1e-8 && power.anchorPrescribedPower == 0)
                let snapshot=try fixture.model.evaluate(fixture.model.makeState(state)),id=GeometricEvolutionFixtures.id
                let am=try snapshot.body(id(.body,"a")).motion,bm=try snapshot.body(id(.body,"b")).motion
                let x=try am.pose.rotation.rotating(.unitX),y=try bm.pose.rotation.rotating(.unitX),dx=try am.velocity.angular.cross(x),dy=try bm.velocity.angular.cross(y)
                let ddx=try am.acceleration.angular.cross(x).adding(am.velocity.angular.cross(dx)),ddy=try bm.acceleration.angular.cross(y).adding(bm.velocity.angular.cross(dy))
                #expect(try x.cross(y).magnitude() < 1e-9);#expect(try dx.subtracting(dy).magnitude() < 1e-9);#expect(try ddx.subtracting(ddy).magnitude() < 1e-8)
            } }
        }
    }
    @Test func actualKnotIsAcceptedExactlyAndFreshColdReplayUsesSameBoundaryWitness() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try TrajectoryEvolutionFixtures(planar:true,piecewise:true),query=TrajectoryFaultBoundaryQuery(),equation=try fixture.equation(query:query)
            let erased:any ProjectedMechanismEquations=equation
            let (session,continuation)=try fixture.session(equation,step:0.7);defer { _=session.shutdown() }
            let codec=NativeRuntimeCheckpointCodec(),saved=try session.checkpoint(codec:codec)
            let final=try ProjectedNonlinearMechanismEvolution().advance(session,equations:erased,continuation:continuation,to:1.4).accepted
            #expect(query.observedAtKnot() && query.callCount() == 3)
            #expect(final.checkpoint.acceptedSteps == 3)
            let freshFixture=try TrajectoryEvolutionFixtures(planar:true,piecewise:true),freshQuery=TrajectoryFaultBoundaryQuery(),freshEquation=try freshFixture.equation(query:freshQuery)
            let (fresh,freshContinuation)=try freshFixture.session(freshEquation,step:0.7);defer { _=fresh.shutdown() }
            _=try fresh.restart(saved,codec:codec)
            let replay=try ProjectedNonlinearMechanismEvolution().advance(fresh,equations:freshEquation,continuation:freshContinuation,to:1.4).accepted
            #expect(replay == final && freshQuery.observedAtKnot())
            let replayBytes=try fresh.checkpoint(codec:codec),finalBytes=try session.checkpoint(codec:codec)
            #expect(replayBytes == finalBytes)
        }
    }
    @Test func legacyCustomSmoothConformerKeepsSourceCompatibilityAndActualCircleEvolution() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let original=try NonlinearMechanismFixtures.equation(NonlinearMechanismFixtures.model())
            let custom:any ProjectedMechanismEquations=LegacySmoothProjectedEquation(original:original)
            let (session,continuation)=try NonlinearMechanismFixtures.session(custom);defer { _=session.shutdown() }
            let final=try ProjectedNonlinearMechanismEvolution().advance(session,equations:custom,continuation:continuation,to:0.02).accepted
            #expect(abs(final.checkpoint.physical.q[0]-cos(0.02)) < 1e-9 && abs(final.checkpoint.physical.q[1]-sin(0.02)) < 1e-9)
        }
    }

}
