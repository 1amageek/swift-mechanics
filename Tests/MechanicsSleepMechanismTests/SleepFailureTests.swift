import SwiftMechanics
import Testing

@Suite struct SleepFailureTests {
    @Test func rejectedTrialRollsBackPhysicalSleepEventsAndRandom() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try SleepFixtures.model(),owner=try SleepFixtures.owner(model,dwell:0),session=try SleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };_=try owner.step(session)
            let before=session.snapshot()
            _=try session.performTrial { (trial,control) throws(RuntimeFailure) in
                try control.beginWorkBlock(units:1);_=try trial.nextRandom();try trial.setVelocity(5,at:0)
                let old=try trial.contributor(owner.schema.id)
                let bad=try RuntimeContributorState(id:old.id,category:old.category,version:old.version,bytes:[])
                try trial.replaceContributor(bad);return .reject
            }
            #expect(session.snapshot() == before)
            #expect(try SleepFixtures.history(owner,session.snapshot()).asleep == [true,true])
            let rejected=try owner.step(session)
            #expect(rejected.accepted.checkpoint.random == before.checkpoint.random)
            #expect(try SleepFixtures.history(owner,rejected.accepted).lastWakeKind == 0)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func staleMissingMalformedAndForgedForceCheckpointsReject() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try SleepFixtures.model(),owner=try SleepFixtures.owner(model,dwell:0),session=try SleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };_=try owner.step(session)
            let accepted=session.snapshot(),checkpoint=accepted.checkpoint,handler=SleepRuntimeCheckpointHandler(sleep:owner,revisions:ReferenceModelRevisionUpdater())
            let index=try #require(checkpoint.contributors.firstIndex(where:{$0.id == owner.schema.id}))
            let record=checkpoint.contributors[index]
            for mode in 0..<5 {
                var records=checkpoint.contributors,sequence=checkpoint.acceptedSteps,physical=checkpoint.physical
                if mode == 0 { sequence+=1 }
                if mode == 1 { records.remove(at:index) }
                if mode == 2 {
                    var bytes=record.bytes;bytes[bytes.count-8]=2
                    records[index]=try RuntimeContributorState(id:record.id,category:record.category,version:record.version,bytes:bytes)
                }
                if mode == 3 {
                    var bytes=record.bytes
                    let start=bytes.count-4*checkpoint.physical.v.count*8
                    let force=Double(6).bitPattern
                    for byte in 0..<8 { bytes[start+byte]=UInt8(truncatingIfNeeded:force >> (8*byte)) }
                    records[index]=try RuntimeContributorState(id:record.id,category:record.category,version:record.version,bytes:bytes)
                }
                if mode == 4 {
                    physical=try KinematicState(revision:model.stamp.revision,time:checkpoint.physical.time+0.1,q:checkpoint.physical.q,v:checkpoint.physical.v,acceleration:checkpoint.physical.acceleration)
                }
                let forged=try RuntimeCheckpoint(model:checkpoint.model,continuation:checkpoint.continuation,physical:physical,contributors:records,
                    random:checkpoint.random,acceptedSteps:sequence)
                #expect(throws:RuntimeFailure.self) { _=try handler.admit(forged,model:model,configuration:session.configuration,cancellation:nil) }
            }
            #expect(session.snapshot() == accepted)
            var work=try SleepFixtures.work()
            #expect(throws:RuntimeFailure.self) { _=try owner.command(session,expected:accepted,drive:[6,0],generation:3,work:&work) }
            _=try owner.step(session)
            #expect(throws:RuntimeFailure.self) { _=try owner.command(session,expected:accepted,drive:[6,0],generation:1,work:&work) }
            let current=session.snapshot()
            let stale=try MechanismSleepImpulse(model:model.stamp,time:accepted.checkpoint.physical.time,acceptedSequence:accepted.checkpoint.acceptedSteps,
                layout:SleepFixtures.layout(),values:[6,0])
            #expect(throws:RuntimeFailure.self) { _=try owner.impact(session,expected:current,impulse:stale,work:&work) }
            #expect(session.snapshot() == current)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func lowNonzeroVelocityAndNonzeroForceNeverOmitRealMotion() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try SleepFixtures.model(v:[1e-10,-0.5e-10]),owner=try SleepFixtures.owner(model,dwell:0),session=try SleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() }
            let result=try owner.step(session)
            #expect(try SleepFixtures.history(owner,result.accepted).asleep == [false,false])
            #expect(result.accepted.checkpoint.physical.q[0] > 0)
            let forcedModel=try SleepFixtures.model(),forcedOwner=try SleepFixtures.owner(forcedModel,dwell:0,adaptive:true,drive:[6,0])
            let forced=try SleepFixtures.session(forcedModel,owner:forcedOwner);defer { _=forced.shutdown() }
            let active=try forcedOwner.step(forced)
            #expect(active.rejectedTrials > 0)
            #expect(try SleepFixtures.history(forcedOwner,active.accepted).asleep == [false,false])
            #expect(active.accepted.checkpoint.acceptedSteps == 1)
            #expect(active.accepted.checkpoint.random == RuntimeRandomState(seed:42))
            #expect(try SleepFixtures.history(forcedOwner,active.accepted).lastWakeKind == 0)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func workCapacityAndRuntimeCancellationPreserveAcceptedPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try SleepFixtures.model(),owner=try SleepFixtures.owner(model,dwell:0),session=try SleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };_=try owner.step(session)
            let before=session.snapshot();var tiny=try SleepFixtures.work(storage:1,operations:1)
            #expect(throws:RuntimeFailure.self) { _=try owner.command(session,expected:before,drive:[6,0],generation:1,work:&tiny) }
            #expect(session.snapshot() == before)
            #expect(throws:RuntimeFailure.self) {
                _=try session.performTrial { (trial,control) throws(RuntimeFailure) in
                    try control.beginWorkBlock(units:1);_=try trial.nextRandom();session.cancel()
                    try control.beginWorkBlock(units:1);return .accept
                }
            }
            #expect(session.snapshot() == before)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
