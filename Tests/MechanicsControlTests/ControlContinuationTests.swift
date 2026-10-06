import SwiftMechanics
import Testing

@Suite struct ControlContinuationTests {
    @Test func coldCheckpointReplayPreservesCompleteAcceptedTuple() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (p,l,c)=try ControlFixtures.plant(ki:2,filter:0.1),s=try ControlFixtures.session(plant:p,law:l,policy:c,mode:.velocity)
        defer { _=s.shutdown() }
        _=try s.step(input:ControlFixtures.input(s,plant:p,value:0.3,mode:.velocity))
        let codec=NativeRuntimeCheckpointCodec(),saved=try s.checkpoint(codec:codec),prefix=try ControlFixtures.observation(s)
        let next=try s.step(input:ControlFixtures.input(s,plant:p,value:0.2,mode:.velocity)),continued=try s.checkpoint(codec:codec)
        try s.restart(saved,codec:codec)
        #expect(try ControlFixtures.observation(s).accepted == prefix.accepted)
        let replay=try s.step(input:ControlFixtures.input(s,plant:p,value:0.2,mode:.velocity))
        #expect(replay.observation.accepted == next.observation.accepted);#expect(try s.checkpoint(codec:codec) == continued)
        #expect(replay.observation.actuator.primary == next.observation.actuator.primary && replay.observation.actuator.secondary == next.observation.actuator.secondary)
    }
    @Test func realPendingPreparationRejectedWithRNGAndPositionChanges() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (p,l,c)=try ControlFixtures.plant(ki:2),factory=ReferenceControlSessionFactory(integrator:ControlRejectingIntegrator())
        let s=try ControlFixtures.session(plant:p,law:l,policy:c,mode:.velocity,factory:factory),reference=try ControlFixtures.session(plant:p,law:l,policy:c,mode:.velocity)
        defer { _=s.shutdown();_=reference.shutdown() }
        let codec=NativeRuntimeCheckpointCodec(),before=try s.checkpoint(codec:codec)
        let error=try ControlFixtures.failure { _=try s.step(input:ControlFixtures.input(s,plant:p,value:0.3,mode:.velocity)) }
        if case .originalEvidenceRejected=error.cause {} else { Issue.record("Expected nonpublished rejected attempt") }
        #expect(try s.checkpoint(codec:codec) == before)
        let actual=try s.step(input:ControlFixtures.input(s,plant:p,value:0.3,mode:.velocity)),expected=try reference.step(input:ControlFixtures.input(reference,plant:p,value:0.3,mode:.velocity))
        #expect(actual.observation.accepted == expected.observation.accepted)
    }
    @Test func pendingAndPhysicalTimeMismatchRefuseRestart() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (p,l,c)=try ControlFixtures.plant(),s=try ControlFixtures.session(plant:p,law:l,policy:c)
        defer { _=s.shutdown() }
        _=try s.step(input:ControlFixtures.input(s,plant:p))
        let original=try ControlFixtures.observation(s).accepted.checkpoint,codec=NativeRuntimeCheckpointCodec(),before=try s.checkpoint(codec:codec)
        var records=original.contributors
        let index=try #require(records.firstIndex(where:{$0.category == .controller}));var bytes=records[index].bytes
        bytes[bytes.count-152+16]=1
        records[index]=try RuntimeContributorState(id:records[index].id,category:.controller,version:1,bytes:bytes)
        let bad=try RuntimeCheckpoint(model:original.model,continuation:original.continuation,physical:original.physical,contributors:records,random:original.random,acceptedSteps:original.acceptedSteps)
        _=try ControlFixtures.failure { try s.restart(codec.encode(bad,capacity:c.runtimeCapacity),codec:codec) }
        #expect(try s.checkpoint(codec:codec) == before)
        let physical=try KinematicState(revision:1,time:0.2,q:original.physical.q,v:original.physical.v,acceleration:original.physical.acceleration)
        let mismatch=try RuntimeCheckpoint(model:original.model,continuation:original.continuation,physical:physical,contributors:original.contributors,random:original.random,acceptedSteps:original.acceptedSteps)
        _=try ControlFixtures.failure { try s.restart(codec.encode(mismatch,capacity:c.runtimeCapacity),codec:codec) }
        #expect(try s.checkpoint(codec:codec) == before)
    }
    @Test func observerReentryFailureAndShutdownUseOriginalOwner() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (p,l,c)=try ControlFixtures.plant(),s=try ControlFixtures.session(plant:p,law:l,policy:c)
        try s.observe { _ throws(ControlFailure) in
            do throws(ControlFailure) { _=try s.checkpoint(codec:NativeRuntimeCheckpointCodec());Issue.record("Reentrant operation accepted") }
            catch { if case .busy=error.cause {} else { Issue.record("Wrong reentry failure") } }
        }
        _=try ControlFixtures.failure { try s.observe { _ throws(ControlFailure) in throw ControlFailure(.invalidInput,phase:"test-observer") } }
        _=try s.step(input:ControlFixtures.input(s,plant:p))
        _=s.shutdown();#expect(s.shutdownStatus() != nil)
        _=try ControlFixtures.failure { _=try s.step(input:ControlFixtures.input(s,plant:p)) }
    }
}
