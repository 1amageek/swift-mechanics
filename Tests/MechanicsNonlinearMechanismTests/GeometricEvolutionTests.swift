import Foundation
import SwiftMechanics
import Testing

@Suite struct GeometricEvolutionTests {
    @Test(.timeLimit(.minutes(1))) func torquedFourbarLongRunOriginalRowsEnergyReactionAndReplay() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(),system=try GeometricEvolutionFixtures.fourbarSystem(fixture)
            var drive=[Double](repeating:0,count:3);drive[fixture.crankIndex]=0.001
            let equation=try GeometricEvolutionFixtures.equation(system,drive:drive)
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.05);defer { _=session.shutdown() }
            let evolution:any ProjectedMechanismEvolving=ProjectedNonlinearMechanismEvolution()
            _=try evolution.advance(session,equations:equation,continuation:continuation,to:5)
            let checkpoint=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            let result=try evolution.advance(session,equations:equation,continuation:continuation,to:10)
            let state=result.accepted.checkpoint.physical
            #expect(fixture.originalClosure(q:state.q).allSatisfy { abs($0) < 3e-9 })
            #expect(fixture.originalVelocity(q:state.q,v:state.v).allSatisfy { abs($0) < 3e-8 })
            #expect(fixture.originalAcceleration(q:state.q,v:state.v,acceleration:state.acceleration).allSatisfy { abs($0) < 3e-8 })
            let kinetic=fixture.originalKineticEnergy(q:state.q,v:state.v)
            let torqueWork=drive[fixture.crankIndex]*(state.q[fixture.crankIndex]-fixture.model.descriptor.initialState.q[fixture.crankIndex])
            #expect(abs(kinetic-torqueWork) < 2e-8)
            let capture=NonlinearTestCapture()
            _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                var work=NumericalWork(budget:equation.publicationBudget)
                let physical=try equation.consistent(time:state.time,point:state.q+state.v,work:&work,control:control)
                capture.store(physical);return .reject
            }
            let physical=try #require(capture.read())
            #expect(abs(physical.kineticEnergy-kinetic) < 1e-10)
            #expect(physical.acceleration.rank.rank == 2)
            #expect(physical.acceleration.rank.reactionNullity == 1)
            let q=state.q,a=q[fixture.crankIndex],b=a+q[fixture.couplerIndex],c=q[fixture.rockerIndex]
            let lambda=physical.acceleration.rowMultipliers,reaction=physical.acceleration.generalizedReaction
            let crankQ=0.5*((-sin(a)-2*sin(b))*lambda[0]+(cos(a)+2*cos(b))*lambda[1])
            let couplerQ = -sin(b)*lambda[0]+cos(b)*lambda[1]
            let rockerQ=sin(c)*lambda[0]-cos(c)*lambda[1]
            #expect(abs(reaction[fixture.crankIndex]-crankQ) < 1e-9)
            #expect(abs(reaction[fixture.couplerIndex]-couplerQ) < 1e-9)
            #expect(abs(reaction[fixture.rockerIndex]-rockerQ) < 1e-9)
            #expect(abs(zip(reaction,state.v).reduce(0) { $0+$1.0*$1.1 }) < 1e-9)
            let history=try continuation.associatedHistory(try #require(result.accepted.checkpoint.contributors.first),physical:state,equations:equation)
            #expect(history.acceptedTime == 10);#expect(history.acceptedPoint == state.q+state.v)
            #expect(result.work.supplierArithmeticCharged > 0)
            _=try session.restart(checkpoint,codec:NativeRuntimeCheckpointCodec())
            let replay=try evolution.advance(session,equations:equation,continuation:continuation,to:10)
            #expect(replay.accepted == result.accepted)
        }
    }
    @Test(.timeLimit(.minutes(1))) func fourbarRefinementAgainstTorqueWorkInvariant() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(),system=try GeometricEvolutionFixtures.fourbarSystem(fixture)
            var drive=[Double](repeating:0,count:3);drive[fixture.crankIndex]=0.5
            var states:[[Double]]=[]
            for step in [0.1,0.05,0.025] {
                let equation=try GeometricEvolutionFixtures.equation(system,drive:drive)
                let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:step);defer { _=session.shutdown() }
                let result=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:1)
                let state=result.accepted.checkpoint.physical
                states.append(state.q+state.v)
                #expect(fixture.originalClosure(q:state.q).allSatisfy { abs($0) < 3e-9 })
                #expect(abs(fixture.originalKineticEnergy(q:state.q,v:state.v)-0.5*(state.q[fixture.crankIndex]-0.5)) < 1e-5)
            }
            let coarse=zip(states[0],states[1]).reduce(0) { $0+($1.0-$1.1)*($1.0-$1.1) }
            let fine=zip(states[1],states[2]).reduce(0) { $0+($1.0-$1.1)*($1.0-$1.1) }
            #expect(coarse > 50*fine)
        }
    }
    @Test(.timeLimit(.minutes(1))) func mixedQuaternionChartsUseActualRetractionAndFullAxisClosure() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try GeometricEvolutionFixtures.mixed(),system=try GeometricEvolutionFixtures.mixedSystem(model)
            let equation=try GeometricEvolutionFixtures.equation(system)
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.02);defer { _=session.shutdown() }
            let result=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:1)
            let state=result.accepted.checkpoint.physical,starts=try GeometricEvolutionFixtures.quaternionStarts(model)
            #expect(state.q.count == 18);#expect(state.v.count == 15)
            for start in starts { #expect(abs(state.q[start..<(start+4)].reduce(0) { $0+$1*$1 }-1) < 1e-9) }
            let snapshot=try model.evaluate(model.makeState(state))
            let sphere=try snapshot.body(GeometricEvolutionFixtures.id(.body,"sphere")),free=try snapshot.body(GeometricEvolutionFixtures.id(.body,"free"))
            let axisA=try sphere.motion.pose.rotation.rotating(.unitX),axisB=try free.motion.pose.rotation.rotating(.unitX)
            #expect(try axisA.cross(axisB).magnitude() < 1e-9)
            #expect(try sphere.motion.pose.translation.subtracting(free.motion.pose.translation).magnitude() < 1e-9)
            let rateA=try sphere.motion.velocity.angular.cross(axisA),rateB=try free.motion.velocity.angular.cross(axisB)
            let secondA=try sphere.motion.acceleration.angular.cross(axisA).adding(sphere.motion.velocity.angular.cross(rateA))
            let secondB=try free.motion.acceleration.angular.cross(axisB).adding(free.motion.velocity.angular.cross(rateB))
            let fullRate=try rateA.cross(axisB).adding(axisA.cross(rateB))
            let fullSecond=try secondA.cross(axisB).adding(rateA.cross(rateB).scaled(by:2)).adding(axisA.cross(secondB))
            #expect(try rateA.magnitude() > 0.6);#expect(try secondA.magnitude() > 0.4)
            #expect(try fullRate.magnitude() < 1e-8);#expect(try fullSecond.magnitude() < 1e-8)
            var work=try GeometricEvolutionFixtures.work()
            let original=try GeometricRelationEvaluator().evaluate(system,state:state,policy:GeometricEvolutionFixtures.evaluation(),work:&work)
            for row in original.velocity.rowIDs.indices {
                var velocity=original.velocity.drift[row],acceleration=original.velocity.accelerationBias[row]
                for i in state.v.indices {
                    velocity+=original.velocity.rows[row*state.v.count+i]*state.v[i]*system.layout.timeScale/system.layout.scales[i]
                    acceleration+=original.velocity.rows[row*state.v.count+i]*state.acceleration[i]*system.layout.timeScale*system.layout.timeScale/system.layout.scales[i]
                }
                #expect(abs(velocity) < 1e-8);#expect(abs(acceleration) < 1e-8)
            }
            let spherical=try GeometricEvolutionFixtures.entry(model,"s"),six=try GeometricEvolutionFixtures.entry(model,"f")
            #expect(abs(state.q[spherical.positions.start]-cos(0.2)) < 1e-6)
            #expect(abs(state.q[six.positions.start+3]-cos(0.2)) < 1e-6)
            #expect(abs(state.q[3]-cos(0.15)) < 1e-6)
        }
    }
    @Test(.timeLimit(.minutes(1))) func analyticMovingTargetPreservesOriginalVelocityAndAcceleration() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try NonlinearMechanismFixtures.model(q:[1,0],v:[0,0.2])
            let first=try GeometricFrameEndpoint(body:NonlinearMechanismFixtures.id(.body,"mass"),frame:NonlinearMechanismFixtures.id(.frame,"mass-frame"))
            let second=try GeometricFrameEndpoint(body:NonlinearMechanismFixtures.id(.body,"root"),frame:NonlinearMechanismFixtures.id(.frame,"root-frame"))
            let target=try GeometricAnalyticTarget(value:Vector3(1,0,0),rate:Vector3(0,0.2,0),second:Vector3(0.1,0,0),referenceTime:0)
            let relation=try GeometricRelation(kind:.coincidence,rowIDs:[1,2,3],first:first,second:second,target:target,scale:1)
            let equation=try GeometricEvolutionFixtures.equation(GeometricEvolutionFixtures.system(model,relations:[relation]))
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.05);defer { _=session.shutdown() }
            let result=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:1)
            let s=result.accepted.checkpoint.physical
            #expect(abs(s.q[0]-1.05) < 1e-9);#expect(abs(s.q[1]-0.2) < 1e-9)
            #expect(abs(s.v[0]-0.1) < 1e-9);#expect(abs(s.v[1]-0.2) < 1e-9)
            #expect(abs(s.acceleration[0]-0.1) < 1e-9);#expect(abs(s.acceleration[1]) < 1e-9)
        }
    }
    @Test(.timeLimit(.minutes(1))) func positionAndVelocityProjectionEnergyAreSeparateActualPhysicalChanges() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(),system=try GeometricEvolutionFixtures.fourbarSystem(fixture)
            let equation=try GeometricEvolutionFixtures.equation(system)
            let (session,_)=try NonlinearMechanismFixtures.session(equation);defer { _=session.shutdown() }
            var q=fixture.model.descriptor.initialState.q;q[fixture.couplerIndex]+=0.01
            var v=[Double](repeating:0,count:3);v[fixture.crankIndex]=0.2;v[fixture.couplerIndex] = -0.1;v[fixture.rockerIndex]=0.3
            let raw=q+v,capture=NonlinearTestCapture(),prefix=session.snapshot()
            _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                var work=NumericalWork(budget:equation.publicationBudget)
                capture.store(try equation.consistent(time:0,point:raw,work:&work,control:control));return .reject
            }
            let result=try #require(capture.read()),position=Array(result.point[..<3]),velocity=Array(result.point[3...])
            let before=fixture.originalKineticEnergy(q:q,v:v),positionEnergy=fixture.originalKineticEnergy(q:position,v:v),after=fixture.originalKineticEnergy(q:position,v:velocity)
            let positionChange=try #require(result.positionProjectionEnergyChange),impulseChange=try #require(result.velocityProjection.kineticEnergyChange)
            #expect(result.positionCorrection > 0);#expect(abs(positionChange) > 1e-8)
            #expect(abs(positionChange-(positionEnergy-before)) < 1e-10)
            #expect(abs(impulseChange-(after-positionEnergy)) < 1e-10)
            #expect(abs(result.kineticEnergy-after) < 1e-10)
            #expect(abs(after-before-positionChange-impulseChange) < 1e-10)
            #expect(session.snapshot() == prefix)
        }
    }

}
