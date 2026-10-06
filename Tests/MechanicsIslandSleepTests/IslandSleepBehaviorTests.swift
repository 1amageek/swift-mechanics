import Testing
import SwiftMechanics

@Suite internal struct IslandSleepBehaviorTests {
    @Test func acceptedMixedRestAndGenuineSupplierOmission() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let observed=IslandSleepObservedDynamics(),owner=try IslandSleepFixtures.owner(drive:[2,2,4],dwell:0.15,dynamics:observed),session=try IslandSleepFixtures.session(owner)
        defer { _=session.shutdown() };var work=try IslandSleepFixtures.work()
        let original=session.snapshot();_=try owner.step(session,work:&work);_=try owner.step(session,work:&work)
        let before=session.snapshot(),h=try IslandSleepFixtures.history(owner,session)
        #expect(h.asleep == [true,false]);#expect(h.acceptedSequence == 2);#expect(h.position[0] == 0 && h.position[1] == 0)
        observed.reset();let omitted=try owner.step(session,work:&work),after=session.snapshot()
        #expect(observed.motionCount(owner.program.islands[0].id) == 0);#expect(observed.motionCount(owner.program.islands[1].id) > 0)
        let dt=after.checkpoint.physical.time-original.checkpoint.physical.time
        #expect(abs(after.checkpoint.physical.q[2]-(0.75-dt+dt*dt)) < 1e-9);#expect(abs(after.checkpoint.physical.v[2]-(-1+2*dt)) < 1e-9)
        #expect(after.checkpoint.physical.acceleration[0] == 0 && after.checkpoint.physical.acceleration[1] == 0);#expect(abs(after.checkpoint.physical.acceleration[2]-2) < 1e-9)
        #expect(after.checkpoint.random == original.checkpoint.random);#expect(before.checkpoint.acceptedSteps+1 == after.checkpoint.acceptedSteps)
        #expect(omitted.work.physical.numerical.operations == work.physical.numerical.operations);#expect(omitted.work.contributorEncoding.operations > 0)
        let awakeObserved=IslandSleepObservedDynamics(),awake=try IslandSleepFixtures.owner(drive:[2,2,4],dwell:10,dynamics:awakeObserved),active=try IslandSleepFixtures.session(awake)
        defer { _=active.shutdown() };var activeWork=try IslandSleepFixtures.work()
        _=try awake.step(active,work:&activeWork);_=try awake.step(active,work:&activeWork);awakeObserved.reset()
        let actual=try awake.step(active,work:&activeWork)
        #expect(awakeObserved.motionCount(awake.program.islands[0].id) > 0);#expect(actual.integration.work.supplierArithmeticCharged > omitted.integration.work.supplierArithmeticCharged)
        #expect(actual.integration.accepted.checkpoint.physical == after.checkpoint.physical)
    }
    @Test func freshColdAdmissionAndExactRestartReplay() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let owner=try IslandSleepFixtures.owner(drive:[2,2,4]),session=try IslandSleepFixtures.session(owner)
        defer { _=session.shutdown() };var work=try IslandSleepFixtures.work();_=try owner.step(session,work:&work);_=try owner.step(session,work:&work)
        let codec=NativeRuntimeCheckpointCodec(),bytes=try session.checkpoint(codec:codec),checkpoint=session.snapshot().checkpoint
        let observed=IslandSleepObservedDynamics(),fresh=try IslandSleepFixtures.owner(drive:[2,2,4],dynamics:observed)
        let admitted=try IslandSleepCheckpointHandler(sleep:fresh,revisions:ReferenceModelRevisionUpdater()).admitWithReport(checkpoint,model:fresh.model,configuration:IslandSleepFixtures.configuration(fresh))
        #expect(admitted.accepted.checkpoint == checkpoint);#expect(observed.restCount > 0);#expect(observed.motionCount(fresh.program.islands[1].id) > 0)
        #expect(admitted.checkpointAdmission.physical.numerical.operations > 0);#expect(admitted.checkpointAdmission.physical.loads.consumed > 0);#expect(admitted.checkpointAdmission.supplierInvocations > 0)
        let restarted=try IslandSleepFixtures.session(fresh);defer { _=restarted.shutdown() };_=try restarted.restart(bytes,codec:codec)
        var freshWork=try IslandSleepFixtures.work();_=try owner.step(session,work:&work);_=try fresh.step(restarted,work:&freshWork)
        #expect(try session.checkpoint(codec:codec) == restarted.checkpoint(codec:codec));#expect(session.snapshot() == restarted.snapshot())
    }
    @Test func isolatedTrajectoryPreservesTheOriginalWholeCheckpoint() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let participant=try IslandSleepParticipant(),owner=try IslandSleepFixtures.owner(drive:[2,2,4],participant:participant),session=try IslandSleepFixtures.session(owner)
        defer { _=session.shutdown() };var work=try IslandSleepFixtures.work();_=try owner.step(session,work:&work)
        let source=session.snapshot(),bytes=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
        let endpoint=try owner.query(from:source,configuration:session.configuration,to:0.35,work:&work)
        #expect(endpoint.source == source.checkpoint);#expect(endpoint.privateAcceptedSteps == 3);#expect(endpoint.physical.time == 0.35)
        #expect(abs(endpoint.physical.q[2]-(0.75-0.35+0.35*0.35)) < 1e-9);#expect(abs(endpoint.physical.v[2]+0.3) < 1e-9)
        #expect(session.snapshot() == source);#expect(try session.checkpoint(codec:NativeRuntimeCheckpointCodec()) == bytes)
        #expect(endpoint.accepted.checkpoint.random == source.checkpoint.random);#expect(work.queries == 1)
        let ih=try owner.continuation.history(#require(endpoint.accepted.checkpoint.contributors.first(where:{$0.id == owner.continuation.schema.id})))
        #expect(ih.acceptedSteps == endpoint.accepted.checkpoint.acceptedSteps);#expect(ih.acceptedSteps != source.checkpoint.acceptedSteps)
    }
    @Test func operationProofSurvivesAnotherSessionCacheReplacement() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let dynamics=IslandSleepObservedDynamics(),owner=try IslandSleepFixtures.owner(dynamics:dynamics),first=try IslandSleepFixtures.session(owner),other=try IslandSleepFixtures.session(owner,physical:IslandSleepFixtures.physical(owner,q:[0.2,-0.2,0.75]))
        defer { _=first.shutdown();_=other.shutdown() };var work=try IslandSleepFixtures.work();_=try owner.step(first,work:&work)
        let evidence=IslandSleepReentryEvidence()
        dynamics.install {
            do { var otherWork=try IslandSleepFixtures.work();_=try owner.step(other,work:&otherWork);evidence.record(true) }
            catch { evidence.record(false) }
        }
        _=try owner.step(first,work:&work)
        #expect(evidence.value == true);#expect(first.snapshot().checkpoint.physical.q[..<2] == [0,0]);#expect(other.snapshot().checkpoint.physical.q[..<2] == [0.2,-0.2])
        #expect(try IslandSleepFixtures.history(owner,first).asleep == [true,false])
    }
    @Test func adaptiveRejectedTrialsUseEachActualPrivateAcceptedSource() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let owner=try IslandSleepFixtures.owner(drive:[2,2,4],method:.heunEuler,errorScale:1e-4),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() }
        let source=session.snapshot();var work=try IslandSleepFixtures.work()
        let endpoint=try owner.query(from:source,configuration:session.configuration,to:0.15,work:&work)
        #expect(endpoint.privateAcceptedSteps > 1);#expect(endpoint.accepted.checkpoint.acceptedSteps == UInt64(endpoint.privateAcceptedSteps));#expect(endpoint.physical.time == 0.15)
        #expect(abs(endpoint.physical.q[2]-(0.75-0.15+0.15*0.15)) < 1e-9);#expect(abs(endpoint.physical.v[2]+0.7) < 1e-9)
        #expect(session.snapshot() == source);#expect(endpoint.accepted.checkpoint.random == source.checkpoint.random)
        let h=try owner.continuation.history(#require(endpoint.accepted.checkpoint.contributors.first(where:{$0.id == owner.continuation.schema.id})))
        #expect(h.normalizedError != nil && h.normalizedError! <= 1);#expect(h.acceptedSteps == endpoint.accepted.checkpoint.acceptedSteps)
    }

}
