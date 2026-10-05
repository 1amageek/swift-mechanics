import Testing
import SwiftMechanics

@Suite internal struct IslandSleepWakeTests {
    @Test(arguments:[0.0,1.0]) func actualRetainedRowImpulseWakesConnectedIslandAtOriginalSequence(_ restitution:Double) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let owner=try IslandSleepFixtures.owner(),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() };var work=try IslandSleepFixtures.work()
        _=try owner.step(session,work:&work);let source=session.snapshot()
        #expect(try IslandSleepFixtures.history(owner,session).asleep == [true,false])
        let endpoint=try owner.query(from:source,configuration:session.configuration,to:0.25,work:&work)
        let impact=try IslandSleepImpactFixtures.impact(owner,endpoint:endpoint,restitution:restitution)
        let candidate=try owner.prepareImpactWake(source:source,endpoint:endpoint,impact:impact,work:&work)
        #expect(candidate.source == source.checkpoint);#expect(candidate.physical.q == endpoint.physical.q);#expect(candidate.physical.time == impact.time);#expect(candidate.physical.v == impact.velocity)
        let impulse=4*(1+restitution)/3
        #expect(abs(candidate.physical.v[0]+impulse/4) < 1e-9);#expect(abs(candidate.physical.v[1]-impulse/4) < 1e-9);#expect(abs(candidate.physical.v[2]-(-1+impulse/2)) < 1e-9)
        #expect(candidate.physical.acceleration.allSatisfy({$0 == 0}));#expect(candidate.affectedIslandIDs.contains(owner.program.islands[0].id))
        let h=try owner.history(candidate.sleep),ih=try owner.continuation.history(candidate.integration)
        #expect(h.asleep == [false,false]);#expect(h.acceptedSequence == source.checkpoint.acceptedSteps+1);#expect(h.wakeSequence == h.acceptedSequence);#expect(h.lastWakeEventID == 41);#expect(h.lastWakeKind == 1)
        #expect(ih.acceptedSteps == h.acceptedSequence);#expect(ih.acceptedSteps != endpoint.accepted.checkpoint.acceptedSteps);#expect(session.snapshot() == source)
        _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units:1)
            for i in candidate.physical.q.indices { try trial.setPosition(candidate.physical.q[i],at:i);try trial.setVelocity(candidate.physical.v[i],at:i);try trial.setAcceleration(candidate.physical.acceleration[i],at:i) }
            try trial.setTime(candidate.physical.time);try trial.replaceContributor(candidate.sleep);try trial.replaceContributor(candidate.integration);return .accept
        }
        #expect(session.snapshot().checkpoint.random == source.checkpoint.random);#expect(session.snapshot().checkpoint.acceptedSteps == source.checkpoint.acceptedSteps+1)
        if restitution == 1 {
            let fresh=try IslandSleepFixtures.owner(),restored=try IslandSleepFixtures.session(fresh);defer { _=restored.shutdown() }
            _=try restored.restart(session.checkpoint(codec:NativeRuntimeCheckpointCodec()),codec:NativeRuntimeCheckpointCodec())
            let wake=session.snapshot().checkpoint.physical;var freshWork=try IslandSleepFixtures.work();_=try owner.step(session,work:&work);_=try fresh.step(restored,work:&freshWork)
            let actual=session.snapshot().checkpoint.physical
            for i in actual.q.indices { #expect(abs(actual.q[i]-(wake.q[i]+0.1*wake.v[i])) < 1e-9);#expect(abs(actual.v[i]-wake.v[i]) < 1e-9) }
            #expect(try session.checkpoint(codec:NativeRuntimeCheckpointCodec()) == restored.checkpoint(codec:NativeRuntimeCheckpointCodec()))
        }
    }
    @Test func staleEndpointCannotMintAnotherOriginalWake() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let owner=try IslandSleepFixtures.owner(),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() };var work=try IslandSleepFixtures.work();_=try owner.step(session,work:&work)
        let source=session.snapshot(),endpoint=try owner.query(from:source,configuration:session.configuration,to:0.25,work:&work),impact=try IslandSleepImpactFixtures.impact(owner,endpoint:endpoint,restitution:1)
        _=try owner.step(session,work:&work);let actual=session.snapshot()
        do { _=try owner.prepareImpactWake(source:actual,endpoint:endpoint,impact:impact,work:&work);Issue.record("Stale source produced wake authority.") }
        catch let error as IslandSleepFailure { if case .runtime(let cause)=error.reason { #expect(cause.code == .invalidContributor) } else { Issue.record("Wrong stale-source failure.") } }
        #expect(session.snapshot() == actual)
    }
}
