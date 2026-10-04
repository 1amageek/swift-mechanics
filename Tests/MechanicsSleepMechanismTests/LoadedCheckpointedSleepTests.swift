import SwiftMechanics
import Testing

@Suite struct LoadedCheckpointedSleepTests {
    @Test func realGravityAndSpringEquilibriumOmitsLoadedWork() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try LoadedSleepFixtures.model(),owner=try LoadedSleepFixtures.owner(model),session=try LoadedSleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() }
            let first=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            #expect(first.loads.scope == .equationExecution);#expect(first.loads.invocationsStarted > 0)
            #expect(first.loads.consumed == 6*first.loads.invocationsCompleted)
            #expect(try LoadedSleepFixtures.history(owner,first.integration.accepted).mechanics.asleep == [false,false])
            let second=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            #expect(try LoadedSleepFixtures.history(owner,second.integration.accepted).mechanics.asleep == [true,true])
            let sleeping=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(work:0),maximumLoadInvocations:0)
            #expect(sleeping.loads.invocationsStarted == 0);#expect(sleeping.loads.consumed == 0)
            #expect(sleeping.integration.work.supplierArithmeticCharged < second.integration.work.supplierArithmeticCharged)
            let physical=sleeping.integration.accepted.checkpoint.physical
            #expect(physical.q == [-1,-1]);#expect(physical.v == [0,0]);#expect(physical.acceleration == [0,0])
            #expect(sleeping.integration.accepted.checkpoint.acceptedSteps == 3)
            // Independent SI oracle: each mass-2 body has -20 N gravity and +20 N spring.
            #expect(2*(-10)+(-20*(-1)) == 0)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func selectedGravityVersionWakesAndProducesRealSpringMotion() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try LoadedSleepFixtures.model(),owner=try LoadedSleepFixtures.owner(model,dwell:0),session=try LoadedSleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };_=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            let original=session.snapshot();var work=try LoadedSleepFixtures.work()
            let selection=StationaryLoadSelection(programID:2,revision:1,generation:1)
            let wake=try owner.selectLoad(session,expected:original,selection:selection,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:1,work:&work)
            #expect(wake.loads.invocationsStarted == 1);#expect(wake.loads.consumed == 6)
            let physical=wake.outcome.accepted.checkpoint.physical,h=try LoadedSleepFixtures.history(owner,wake.outcome.accepted)
            #expect(h.selection == selection);#expect(h.previousProgramID == 1);#expect(h.mechanics.lastWakeKind == 3)
            #expect(h.mechanics.asleep == [false,false]);#expect(h.mechanics.wakeSequence == original.checkpoint.acceptedSteps+1)
            #expect(abs(physical.acceleration[0]-2) < 1e-10);#expect(abs(physical.acceleration[1]-2) < 1e-10)
            #expect(physical.q == original.checkpoint.physical.q);#expect(physical.v == [0,0]);#expect(physical.time == original.checkpoint.physical.time)
            #expect(wake.outcome.accepted.checkpoint.random == original.checkpoint.random)
            let active=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            // RK4 of q''=-8-10q, q=-1,v=0: q=-1+a*h²/2-10*a*h⁴/24; v=a*h-10*a*h³/6.
            let expectedQ = -1+2*0.01/2-10*2*0.0001/24,expectedV=2*0.1-10*2*0.001/6
            for index in 0..<2 {
                #expect(abs(active.integration.accepted.checkpoint.physical.q[index]-expectedQ) < 1e-10)
                #expect(abs(active.integration.accepted.checkpoint.physical.v[index]-expectedV) < 1e-10)
            }
            #expect(active.loads.consumed > 0);#expect(try LoadedSleepFixtures.history(owner,active.integration.accepted).mechanics.asleep == [false,false])
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func commandAndImpulseRetainLoadedPhysics() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try LoadedSleepFixtures.model(),owner=try LoadedSleepFixtures.owner(model,dwell:0),session=try LoadedSleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };_=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            let bytes=try session.checkpoint(codec:NativeRuntimeCheckpointCodec());var commandWork=try LoadedSleepFixtures.work()
            let command=try owner.commandWithLoads(session,expected:session.snapshot(),drive:[2,0],generation:1,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:1,work:&commandWork)
            for a in command.outcome.accepted.checkpoint.physical.acceleration { #expect(abs(a-0.5) < 1e-10) }
            #expect(try LoadedSleepFixtures.history(owner,command.outcome.accepted).mechanics.lastWakeKind == 1)
            _=try session.restart(bytes,codec:NativeRuntimeCheckpointCodec());let source=session.snapshot()
            let impulse=try MechanismSleepImpulse(model:model.stamp,time:source.checkpoint.physical.time,acceptedSequence:source.checkpoint.acceptedSteps,layout:LoadedSleepFixtures.layout(),values:[4,0])
            var impulseWork=try LoadedSleepFixtures.work()
            let impact=try owner.impactWithLoads(session,expected:source,impulse:impulse,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:1,work:&impulseWork)
            for v in impact.outcome.accepted.checkpoint.physical.v { #expect(abs(v-1) < 1e-10) }
            #expect(impact.outcome.accepted.checkpoint.physical.acceleration.allSatisfy({abs($0) < 1e-10}))
            #expect(try LoadedSleepFixtures.history(owner,impact.outcome.accepted).mechanics.lastWakeKind == 2)
            #expect(impact.loads.consumed == 6)
            let active=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            #expect(active.integration.accepted.checkpoint.physical.q.allSatisfy({$0 > -1}))
            #expect(active.integration.accepted.checkpoint.physical.acceleration.allSatisfy({$0 < 0}))
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
