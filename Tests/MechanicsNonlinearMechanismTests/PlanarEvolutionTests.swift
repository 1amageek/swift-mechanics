import Foundation
import SwiftMechanics
import Testing

@Suite struct PlanarEvolutionTests {
    @Test(.timeLimit(.minutes(1))) func torquedPlanarFourbarOriginalPhysicsLongRunAndColdExactReplay() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(planar:true),equation=try PlanarEvolutionFixtures.equation(fixture)
            let (session,continuation)=try PlanarEvolutionFixtures.session(equation);defer { _=session.shutdown() }
            let evolution:any ProjectedMechanismEvolving=ProjectedNonlinearMechanismEvolution(),codec=NativeRuntimeCheckpointCodec()
            _=try evolution.advance(session,equations:equation,continuation:continuation,to:5)
            let saved=try session.checkpoint(codec:codec)
            let result=try evolution.advance(session,equations:equation,continuation:continuation,to:10),state=result.accepted.checkpoint.physical
            #expect(fixture.originalClosure(q:state.q).allSatisfy { abs($0) < 3e-9 })
            #expect(fixture.originalVelocity(q:state.q,v:state.v).allSatisfy { abs($0) < 3e-8 })
            #expect(fixture.originalAcceleration(q:state.q,v:state.v,acceleration:state.acceleration).allSatisfy { abs($0) < 3e-8 })
            let kinetic=fixture.originalKineticEnergy(q:state.q,v:state.v)
            #expect(abs(kinetic-0.001*(state.q[fixture.crankIndex]-0.5)) < 2e-8)
            let capture=NonlinearTestCapture()
            _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                var work=NumericalWork(budget:equation.publicationBudget)
                capture.store(try equation.consistent(time:state.time,point:state.q+state.v,work:&work,control:control))
                _=try trial.nextRandom();return .reject
            }
            let accepted=try #require(capture.read()),energy=try #require(accepted.mechanicalEnergy)
            #expect(abs(energy.kineticEnergy-kinetic) < 1e-10)
            #expect(abs(energy.requiredVirtualPower-0.001*state.v[fixture.crankIndex]) < 1e-8)
            #expect(energy.requiredPrescribedPower == 0)
            #expect(accepted.acceleration.rank.rank == 2);#expect(accepted.acceleration.rank.reactionNullity == 1)
            #expect(accepted.acceleration.rowIDs == [501,502,503]);#expect(accepted.acceleration.rowMultipliers[2] == 0)
            #expect(abs(zip(accepted.acceleration.generalizedReaction,state.v).reduce(0) { $0+$1.0*$1.1 }) < 1e-9)
            let originalForce=fixture.originalInertiaForce(q:state.q,v:state.v,acceleration:state.acceleration)
            for i in state.v.indices { #expect(abs(originalForce[i]-equation.drive[i]-accepted.acceleration.generalizedReaction[i]) < 1e-8) }
            #expect(session.snapshot() == result.accepted)
            let history=try continuation.associatedHistory(try #require(result.accepted.checkpoint.contributors.first),physical:state,equations:equation)
            #expect(history.acceptedPoint == state.q+state.v);#expect(history.acceptedTime == state.time)
            let finalBytes=try session.checkpoint(codec:codec)
            _=try session.restart(saved,codec:codec)
            #expect(try evolution.advance(session,equations:equation,continuation:continuation,to:10).accepted == result.accepted)
            #expect(try session.checkpoint(codec:codec) == finalBytes)
            let freshFixture=try GeometricEvolutionFourBar(planar:true),freshEquation=try PlanarEvolutionFixtures.equation(freshFixture)
            let (fresh,freshContinuation)=try PlanarEvolutionFixtures.session(freshEquation);defer { _=fresh.shutdown() }
            _=try fresh.restart(saved,codec:codec)
            #expect(try evolution.advance(fresh,equations:freshEquation,continuation:freshContinuation,to:10).accepted == result.accepted)
            #expect(try fresh.checkpoint(codec:codec) == finalBytes)
        }
    }
    @Test(.timeLimit(.minutes(1))) func physicalSpatialInitializerKeepsExistingChartAndInitialPlanarEffectiveInertia() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let spatial=try GeometricEvolutionFourBar(),geometry=try GeometricEvolutionFixtures.fourbarSystem(spatial)
            var drive=[Double](repeating:0,count:3);drive[spatial.crankIndex]=0.001
            let legacy=try GeometricEvolutionFixtures.equation(geometry,drive:drive),physical=try PlanarEvolutionFixtures.equation(spatial)
            #expect(legacy.descriptor == physical.descriptor)
            let fixture=try GeometricEvolutionFourBar(planar:true),equation=try PlanarEvolutionFixtures.equation(fixture,torque:0.5)
            let (session,_)=try PlanarEvolutionFixtures.session(equation);defer { _=session.shutdown() }
            let initial=fixture.model.descriptor.initialState,q=initial.q,a=q[fixture.crankIndex],b=a+q[fixture.couplerIndex],c=q[fixture.rockerIndex]
            let jx = -sin(a)-2*sin(b),jy=cos(a)+2*cos(b),bx = -2*sin(b),by=2*cos(b),cx=2*sin(c),cy = -2*cos(c)
            let determinant=bx*cy-cx*by
            var tangent=[Double](repeating:0,count:3);tangent[fixture.crankIndex]=1
            tangent[fixture.couplerIndex]=(-jx*cy+cx*jy)/determinant;tangent[fixture.rockerIndex]=(-bx*jy+jx*by)/determinant
            let effective=2*fixture.originalKineticEnergy(q:q,v:tangent),capture=NonlinearTestCapture()
            _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                var work=NumericalWork(budget:equation.publicationBudget)
                capture.store(try equation.consistent(time:0,point:initial.q+initial.v,work:&work,control:control));return .reject
            }
            let result=try #require(capture.read())
            for i in tangent.indices { #expect(abs(result.acceleration.values[i]-0.5*tangent[i]/effective) < 1e-9) }
        }
    }
    @Test(.timeLimit(.minutes(1))) func planarFourbarRefinementAndIndependentTorqueWork() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(planar:true),equation=try PlanarEvolutionFixtures.equation(fixture,torque:0.5)
            var states:[[Double]]=[]
            for step in [0.1,0.05,0.025] {
                let (session,continuation)=try PlanarEvolutionFixtures.session(equation,step:step);defer { _=session.shutdown() }
                let state=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:1).accepted.checkpoint.physical
                states.append(state.q+state.v)
                #expect(fixture.originalAcceleration(q:state.q,v:state.v,acceleration:state.acceleration).allSatisfy { abs($0) < 3e-8 })
                #expect(abs(fixture.originalKineticEnergy(q:state.q,v:state.v)-0.5*(state.q[fixture.crankIndex]-0.5)) < 1e-5)
            }
            let coarse=zip(states[0],states[1]).reduce(0) { $0+pow($1.0-$1.1,2) }
            let fine=zip(states[1],states[2]).reduce(0) { $0+pow($1.0-$1.1,2) }
            #expect(coarse > 50*fine)
        }
    }
    @Test(.timeLimit(.minutes(1))) func geometricTangentAccelerationForgeryStillFailsOriginalForceColdAdmission() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(planar:true),equation=try PlanarEvolutionFixtures.equation(fixture,torque:0.5)
            let (session,continuation)=try PlanarEvolutionFixtures.session(equation);defer { _=session.shutdown() }
            _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.1)
            let prefix=session.snapshot(),old=prefix.checkpoint,s=old.physical,codec=NativeRuntimeCheckpointCodec()
            let saved=try session.checkpoint(codec:codec),a=s.q[fixture.crankIndex],b=a+s.q[fixture.couplerIndex],c=s.q[fixture.rockerIndex]
            let jx = -sin(a)-2*sin(b),jy=cos(a)+2*cos(b),bx = -2*sin(b),by=2*cos(b),cx=2*sin(c),cy = -2*cos(c)
            let determinant=bx*cy-cx*by
            var forged=s.acceleration
            forged[fixture.crankIndex]+=0.2;forged[fixture.couplerIndex]+=0.2*(-jx*cy+cx*jy)/determinant
            forged[fixture.rockerIndex]+=0.2*(-bx*jy+jx*by)/determinant
            #expect(fixture.originalAcceleration(q:s.q,v:s.v,acceleration:forged).allSatisfy { abs($0) < 3e-8 })
            let physical=try KinematicState(revision:s.revision,time:s.time,q:s.q,v:s.v,acceleration:forged)
            let checkpoint=try RuntimeCheckpoint(model:old.model,continuation:old.continuation,physical:physical,contributors:old.contributors,random:old.random,acceptedSteps:old.acceptedSteps)
            let bytes=try codec.encode(checkpoint,capacity:session.configuration.capacity)
            do throws(RuntimeFailure) { _=try session.restart(bytes,codec:codec);Issue.record("Geometric tangent forgery bypassed original force") }
            catch { #expect(error.code == .invalidState) }
            #expect(session.snapshot() == prefix);#expect(try session.checkpoint(codec:codec) == saved)
        }
    }
    @Test(.timeLimit(.minutes(1))) func sameIDsChangedPolarInertiaCannotRebindHistoryAndLegacySupplierCannotAdmitPlanar() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(planar:true),equation=try PlanarEvolutionFixtures.equation(fixture)
            let (source,_)=try PlanarEvolutionFixtures.session(equation);defer { _=source.shutdown() }
            let codec=NativeRuntimeCheckpointCodec(),saved=try source.checkpoint(codec:codec)
            let changed=try GeometricEvolutionFourBar(planar:true,polarScale:1.2),changedEquation=try PlanarEvolutionFixtures.equation(changed)
            #expect(changed.model.stamp == fixture.model.stamp);#expect(changedEquation.descriptor.chart != equation.descriptor.chart)
            let (target,_)=try PlanarEvolutionFixtures.session(changedEquation);defer { _=target.shutdown() };let before=target.snapshot()
            do throws(RuntimeFailure) { _=try target.restart(saved,codec:codec);Issue.record("Changed planar inertia rebound old history") }
            catch { #expect(error.code == .incompatibleContinuation) }
            #expect(target.snapshot() == before)
            let geometry=try GeometricEvolutionFixtures.fourbarSystem(fixture)
            let admission=try NonlinearMechanismFixtures.admission()
            do throws(RuntimeFailure) {
                _=try GeometricMechanismEquation(identity:equation.descriptor.identity,geometry:geometry,drive:equation.drive,policy:equation.policy,
                    projection:equation.projection,maximumStageChartCorrection:equation.maximumStageChartCorrection,publicationBudget:equation.publicationBudget,
                    admission:admission,maximumIdentityBytes:50000)
                Issue.record("Legacy-only supplier admitted planar source")
            } catch { #expect(error.code == .invalidState) }
        }
    }
}
