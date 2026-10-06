import Testing
import SwiftMechanics
@Suite internal struct IslandSleepSmoothTests {
    @Test func queriedMixedEndpointPublishesAtOriginalSequenceAndReplays() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let owner=try IslandSleepFixtures.owner(drive:[2,2,4]),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() }
        var work=try IslandSleepFixtures.work();_=try owner.step(session,work:&work)
        let source=session.snapshot(),endpoint=try owner.query(from:source,configuration:session.configuration,to:0.35,work:&work)
        let queried=try owner.history(#require(endpoint.accepted.checkpoint.contributors.first(where:{$0.id == owner.schema.id})))
        let candidate=try owner.prepareSmoothEndpoint(source:source,endpoint:endpoint,work:&work),h=try owner.history(candidate.sleep),ih=try owner.continuation.history(candidate.integration)
        #expect(h.acceptedSequence == source.checkpoint.acceptedSteps+1);#expect(h.acceptedSequence != endpoint.accepted.checkpoint.acceptedSteps)
        #expect(h.asleep == queried.asleep && h.restSince == queried.restSince);#expect(h.asleep == [true,false]);#expect(h.wakeSequence == queried.wakeSequence)
        #expect(ih.acceptedSteps == h.acceptedSequence);#expect(candidate.physical == endpoint.physical)
        let outcome=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision in
            try control.beginWorkBlock(units:1)
            for i in candidate.physical.q.indices { try trial.setPosition(candidate.physical.q[i],at:i) }
            for i in candidate.physical.v.indices { try trial.setVelocity(candidate.physical.v[i],at:i);try trial.setAcceleration(candidate.physical.acceleration[i],at:i) }
            try trial.setTime(candidate.physical.time);try trial.replaceContributor(candidate.sleep);try trial.replaceContributor(candidate.integration);return .accept
        }
        #expect(outcome.accepted.checkpoint.acceptedSteps == h.acceptedSequence);#expect(outcome.accepted.checkpoint.random == source.checkpoint.random)
        let codec=NativeRuntimeCheckpointCodec(),bytes=try session.checkpoint(codec:codec),fresh=try IslandSleepFixtures.owner(drive:[2,2,4]),restored=try IslandSleepFixtures.session(fresh);defer { _=restored.shutdown() }
        _=try restored.restart(bytes,codec:codec);#expect(try restored.checkpoint(codec:codec) == bytes);#expect(restored.snapshot() == session.snapshot())
    }
    @Test(arguments:[false,true]) func foreignOrStaleSmoothAuthorityRefuses(stale:Bool) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let owner=try IslandSleepFixtures.owner(),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() };var work=try IslandSleepFixtures.work()
        _=try owner.step(session,work:&work);let source=session.snapshot(),endpoint=try owner.query(from:source,configuration:session.configuration,to:0.35,work:&work)
        let consumer=try stale ? owner : IslandSleepFixtures.owner()
        if stale { _=try owner.step(session,work:&work) }
        let prefix=session.snapshot()
        do { _=try consumer.prepareSmoothEndpoint(source:prefix,endpoint:endpoint,work:&work);Issue.record("Foreign or stale smooth authority accepted.") }
        catch { if case .runtime(let failure)=error.reason { #expect(failure.code == .invalidContributor) } else { Issue.record("Unexpected failure.") } }
        #expect(session.snapshot() == prefix);#expect(prefix.checkpoint.random == source.checkpoint.random)
    }
    @Test func smoothEncodingCapacityRetainsOriginalPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let owner=try IslandSleepFixtures.owner(),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() };var work=try IslandSleepFixtures.work()
        _=try owner.step(session,work:&work);let source=session.snapshot(),endpoint=try owner.query(from:source,configuration:session.configuration,to:0.35,work:&work)
        work.contributorEncoding=NumericalWork(budget:try NumericalBudget(scalarStorage:0,arithmeticOperations:0,iterations:0))
        do { _=try owner.prepareSmoothEndpoint(source:source,endpoint:endpoint,work:&work);Issue.record("Zero encoding capacity accepted.") }
        catch { #expect(error.accepted == source);#expect(!error.work.failedSupplierWorkUnavailable) }
        #expect(session.snapshot() == source);#expect(work.contributorEncoding.operations == 0)
    }
}
