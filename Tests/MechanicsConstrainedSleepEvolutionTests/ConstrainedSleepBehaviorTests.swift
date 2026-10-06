import Testing
import SwiftMechanics
@Suite internal struct ConstrainedSleepBehaviorTests {
    @Test(arguments:[0.0,1.0]) func genuineDirectedImpactWakesConnectedGear(restitution:Double) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let f=try ConstrainedSleepFixtures(restitution:restitution);defer { _=f.session.shutdown() };try f.enterSleep()
        let source=f.session.snapshot(),sleepHistory=try ConstrainedSleepSleepFixtures.history(f.sleep,f.session)
        #expect(sleepHistory.asleep == [true,false]);#expect(source.checkpoint.physical.v[2] == -1)
        let before=f.session.profile(),result=try f.service.advanceToNextImpact(f.session,through:0.4,work:f.work(),cancellation:f.token),impact=try #require(result.impact),accepted=result.accepted.checkpoint
        let impulse=4*(1+restitution)/3
        #expect(abs(accepted.physical.time-0.25)<1e-9);#expect(abs(accepted.physical.q[2]-0.5)<1e-9);#expect(accepted.physical.q[0] == 0 && accepted.physical.q[1] == 0)
        #expect(abs(impact.contactImpulse-impulse)<1e-9);#expect(abs(impact.retainedImpulses[0]-impulse/2)<1e-9)
        let velocities=[-impulse/4,impulse/4,-1+impulse/2]
        for i in 0..<3 { #expect(abs(accepted.physical.v[i]-velocities[i])<1e-9);#expect(abs(accepted.physical.acceleration[i])<1e-9) }
        #expect(abs(accepted.physical.v[0]+accepted.physical.v[1])<1e-10);#expect(abs(impact.kineticEnergyBefore-1)<1e-9)
        #expect(abs(impact.kineticEnergyAfter-(restitution == 1 ? 1 : 1.0/3))<1e-9);#expect(abs(impact.predictedLostEnergy-(restitution == 1 ? 0 : 2.0/3))<1e-9)
        for i in 0..<3 { #expect(abs(2*(accepted.physical.v[i]-source.physical.state.v[i])-impact.source.impact.normalRows[i]*impulse-impact.retainedGeneralizedImpulse[i])<1e-9) }
        #expect(accepted.acceptedSteps == source.checkpoint.acceptedSteps+1);#expect(accepted.random == source.checkpoint.random)
        #expect(f.session.profile().committedTransactions == before.committedTransactions+1)
        let history=try f.eventHistory(result.accepted),wake=try ConstrainedSleepSleepFixtures.history(f.sleep,f.session)
        #expect(history.impactCount == 1 && history.lastEventID == 41);#expect(history.sourceSequence == source.checkpoint.acceptedSteps && history.targetSequence == accepted.acceptedSteps)
        #expect(history.acceptedSequence == accepted.acceptedSteps);#expect(wake.asleep == [false,false]);#expect(wake.lastWakeEventID == 41)
        #expect(result.work.queries>2 && result.work.rootIterations>0);#expect(result.work.acceptedSegments == 1 && result.work.acceptedImpacts == 1)
        #expect(result.work.numerical.operations>0 && result.work.contact.operations>0 && result.work.loads.consumed>0);#expect(result.work.checkpointAdmission != nil)
        if restitution == 1 {
            var work=try ConstrainedSleepSleepFixtures.work(token:f.token);_=try f.sleep.step(f.session,work:&work)
            let later=f.session.snapshot().checkpoint.physical,dt=later.time-accepted.physical.time
            for i in 0..<3 { #expect(abs(later.q[i]-accepted.physical.q[i]-dt*velocities[i])<1e-9);#expect(abs(later.v[i]-velocities[i])<1e-9) }
            #expect(try f.eventHistory(f.session.snapshot()).impactCount == 1)
        } else {
            let prefix=f.session.snapshot()
            let attemptedWork=try f.work()
        do throws(ConstrainedSleepEvolutionFailure) { _=try f.service.advanceToNextImpact(f.session,through:0.4,work:attemptedWork,cancellation:f.token);Issue.record("Unsupported plastic support advanced.") }
            catch { if case .hybrid(.unsupportedDomain)=error.cause {} else { Issue.record("Wrong support refusal.") };#expect(error.accepted == prefix) }
            #expect(f.session.snapshot() == prefix)
        }
    }
    @Test(arguments:[0.65,0.9]) func rootUsesActualGeometryAndFreshReplay(position:Double) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let f=try ConstrainedSleepFixtures(q:position,time:0.2);defer { _=f.session.shutdown() };try f.enterSleep()
        let codec=NativeRuntimeCheckpointCodec(),bytes=try f.session.checkpoint(codec:codec),source=f.session.snapshot()
        let fresh=try ConstrainedSleepFixtures(q:position,time:0.2);defer { _=fresh.session.shutdown() }
        let handler=IslandSleepCheckpointHandler(sleep:fresh.sleep,revisions:ReferenceModelRevisionUpdater()),cold=try handler.admitWithReport(source.checkpoint,model:fresh.sleep.model,configuration:fresh.session.configuration)
        #expect(cold.checkpointAdmission.supplierInvocations>0);#expect(cold.checkpointAdmission.physical.numerical.operations>0)
        _=try fresh.session.restart(bytes,codec:codec)
        let result=try f.service.advanceToNextImpact(f.session,through:0.8,work:f.work(),cancellation:f.token)
        _=try fresh.service.advanceToNextImpact(fresh.session,through:0.8,work:fresh.work(),cancellation:fresh.token)
        #expect(abs(result.accepted.checkpoint.physical.time-(0.2+position-0.5))<1e-9)
        #expect(try f.session.checkpoint(codec:codec) == fresh.session.checkpoint(codec:codec));#expect(f.session.snapshot() == fresh.session.snapshot())
    }
    @Test func noImpactSmoothEndpointPreservesMixedHistoryAtOneOuterSequence() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let f=try ConstrainedSleepFixtures();defer { _=f.session.shutdown() };try f.enterSleep();let source=f.session.snapshot()
        let result=try f.service.advanceToNextImpact(f.session,through:0.18,work:f.work(),cancellation:f.token)
        #expect(result.impact == nil);#expect(result.accepted.checkpoint.acceptedSteps == source.checkpoint.acceptedSteps+1);#expect(result.accepted.checkpoint.random == source.checkpoint.random)
        #expect(abs(result.accepted.checkpoint.physical.q[2]-0.57)<1e-10);#expect(result.accepted.checkpoint.physical.time == 0.18)
        #expect(try ConstrainedSleepSleepFixtures.history(f.sleep,f.session).asleep == [true,false]);#expect(try f.eventHistory(result.accepted).impactCount == 0)
        let next=try f.service.advanceToNextImpact(f.session,through:0.4,work:f.work(),cancellation:f.token)
        #expect(next.impact != nil);#expect(next.accepted.checkpoint.acceptedSteps == result.accepted.checkpoint.acceptedSteps+1)
    }
    @Test func zeroDurationDoesNotPublishOrMintEvent() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let f=try ConstrainedSleepFixtures();defer { _=f.session.shutdown() };let source=f.session.snapshot(),before=f.session.profile()
        let result=try f.service.advanceToNextImpact(f.session,through:source.physical.state.time,work:f.work(),cancellation:f.token)
        #expect(result.accepted == source && result.impact == nil);#expect(result.work.acceptedSegments == 0 && result.work.queries == 0);#expect(f.session.profile() == before)
    }
}
