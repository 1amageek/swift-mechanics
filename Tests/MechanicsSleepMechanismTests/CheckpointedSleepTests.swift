import SwiftMechanics
import Testing

@Suite struct CheckpointedSleepTests {
    @Test func acceptedDwellOmissionAndConstantCommandWakeUseActualGears() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try SleepFixtures.model(),owner=try SleepFixtures.owner(model),session=try SleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() }
            let first=try owner.step(session)
            #expect(try SleepFixtures.history(owner,first.accepted).asleep == [false,false])
            let second=try owner.step(session)
            #expect(try SleepFixtures.history(owner,second.accepted).asleep == [true,true])
            let sleeping=try owner.step(session)
            #expect(sleeping.accepted.checkpoint.physical.q == [0,0]);#expect(sleeping.accepted.checkpoint.physical.v == [0,0])
            #expect(sleeping.accepted.checkpoint.physical.acceleration == [0,0])
            #expect(sleeping.work.supplierArithmeticCharged < second.work.supplierArithmeticCharged)
            #expect(sleeping.accepted.checkpoint.acceptedSteps == 3)
            let bytes=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            let source=session.snapshot();var work=try SleepFixtures.work()
            let wake=try owner.command(session,expected:source,drive:[6,0],generation:1,work:&work)
            let history=try SleepFixtures.history(owner,wake.accepted)
            #expect(history.asleep == [false,false]);#expect(history.commandGeneration == 1)
            #expect(history.lastWakeKind == 1);#expect(history.lastWakeCoordinates == [true,true])
            #expect(abs(wake.accepted.checkpoint.physical.acceleration[0]-2) < 1e-10)
            #expect(abs(wake.accepted.checkpoint.physical.acceleration[1]+1) < 1e-10)
            let active=try owner.step(session),physical=active.accepted.checkpoint.physical
            #expect(abs(physical.q[0]-0.01) < 1e-10);#expect(abs(physical.q[1]+0.005) < 1e-10)
            #expect(abs(physical.v[0]-0.2) < 1e-10);#expect(abs(physical.v[1]+0.1) < 1e-10)
            #expect(abs(physical.q[0]+2*physical.q[1]) < 1e-10);#expect(abs(physical.v[0]+2*physical.v[1]) < 1e-10)
            _=try session.restart(bytes,codec:NativeRuntimeCheckpointCodec());var replayWork=try SleepFixtures.work()
            _=try owner.command(session,expected:session.snapshot(),drive:[6,0],generation:1,work:&replayWork)
            let replay=try owner.step(session);#expect(replay.accepted == active.accepted)
            #expect(replay.accepted.checkpoint.random == source.checkpoint.random)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func realInstantaneousMassImpulseWakesConnectedGearsAndMoves() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try SleepFixtures.model(),owner=try SleepFixtures.owner(model,dwell:0),session=try SleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() }
            _=try owner.step(session)
            let source=session.snapshot(),bytes=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            #expect(try SleepFixtures.history(owner,source).asleep == [true,true])
            let impulse=try MechanismSleepImpulse(model:model.stamp,time:source.checkpoint.physical.time,acceptedSequence:source.checkpoint.acceptedSteps,
                layout:SleepFixtures.layout(),values:[6,0])
            var work=try SleepFixtures.work()
            let wake=try owner.impact(session,expected:source,impulse:impulse,work:&work),physical=wake.accepted.checkpoint.physical
            // Actual M=diag(2,4), constrained v0+2*v1=0 gives v=[2,-1].
            #expect(abs(physical.v[0]-2) < 1e-10);#expect(abs(physical.v[1]+1) < 1e-10)
            #expect(abs(2*physical.v[0]-6+2) < 1e-10);#expect(abs(4*physical.v[1]+4) < 1e-10)
            #expect(try SleepFixtures.history(owner,wake.accepted).lastWakeKind == 2)
            #expect(try SleepFixtures.history(owner,wake.accepted).asleep == [false,false])
            let active=try owner.step(session)
            #expect(abs(active.accepted.checkpoint.physical.q[0]-0.2) < 1e-10)
            #expect(abs(active.accepted.checkpoint.physical.q[1]+0.1) < 1e-10)
            _=try session.restart(bytes,codec:NativeRuntimeCheckpointCodec());var replayWork=try SleepFixtures.work()
            _=try owner.impact(session,expected:session.snapshot(),impulse:impulse,work:&replayWork)
            #expect(try owner.step(session).accepted == active.accepted)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
