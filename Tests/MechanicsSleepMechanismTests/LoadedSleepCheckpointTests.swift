import SwiftMechanics
import Testing

@Suite struct LoadedSleepCheckpointTests {
    @Test func freshColdAdmissionHasSeparateLoadReceiptAndExactReplay() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try LoadedSleepFixtures.model(),owner=try LoadedSleepFixtures.owner(model,dwell:0),session=try LoadedSleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };_=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            let before=session.snapshot(),bytes=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            let fresh=try LoadedSleepFixtures.owner(model,dwell:0),handler=LoadedSleepRuntimeCheckpointHandler(sleep:fresh,revisions:ReferenceModelRevisionUpdater())
            let admission=try handler.admitWithLoadReport(before.checkpoint,model:model,configuration:LoadedSleepFixtures.configuration(fresh))
            #expect(admission.accepted == before);#expect(admission.loads.scope == .checkpointAdmission)
            #expect(admission.loads.invocationsStarted == 1);#expect(admission.loads.invocationsCompleted == 1);#expect(admission.loads.consumed == 6)
            let restored=try LoadedSleepFixtures.session(model,owner:fresh);defer { _=restored.shutdown() }
            _=try restored.restart(bytes,codec:NativeRuntimeCheckpointCodec())
            let selection=StationaryLoadSelection(programID:2,revision:1,generation:1)
            var work=try LoadedSleepFixtures.work(),replayWork=try LoadedSleepFixtures.work()
            _=try owner.selectLoad(session,expected:session.snapshot(),selection:selection,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:1,work:&work)
            _=try fresh.selectLoad(restored,expected:restored.snapshot(),selection:selection,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:1,work:&replayWork)
            let actual=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            let replay=try fresh.stepWithLoads(restored,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            #expect(actual.integration.accepted == replay.integration.accepted)
            #expect(actual.loads.consumed == replay.loads.consumed)
            #expect(actual.integration.accepted.checkpoint.random == before.checkpoint.random)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test(arguments:[0,1,2]) func equalIdentityChangedPhysicalLawCannotRestore(mode:Int) throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try LoadedSleepFixtures.model(),owner=try LoadedSleepFixtures.owner(model,dwell:0),session=try LoadedSleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };_=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            let altered=try LoadedSleepFixtures.model(mass:mode == 0 ? 3 : 2)
            #expect(altered.stamp == model.stamp);#expect(altered.tree.layout == model.tree.layout)
            let replacement=try LoadedSleepFixtures.owner(altered,dwell:0,energyScale:mode == 1 ? 2 : 1,stiffness:mode == 2 ? 21 : 20)
            let handler=LoadedSleepRuntimeCheckpointHandler(sleep:replacement,revisions:ReferenceModelRevisionUpdater())
            #expect(throws:LoadedSleepAdmissionFailure.self) { _=try handler.admitWithLoadReport(session.snapshot().checkpoint,model:altered,configuration:LoadedSleepFixtures.configuration(replacement)) }
            #expect(replacement.descriptor.chart != owner.descriptor.chart)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func malformedSourceHistoryAndColdCapacityRejectBeforePublication() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try LoadedSleepFixtures.model(),owner=try LoadedSleepFixtures.owner(model,dwell:0),session=try LoadedSleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };_=try owner.stepWithLoads(session,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            let checkpoint=session.snapshot().checkpoint
            for mode in 0..<4 {
                let fresh=try LoadedSleepFixtures.owner(model,dwell:0),handler=LoadedSleepRuntimeCheckpointHandler(sleep:fresh,revisions:ReferenceModelRevisionUpdater())
                var records=checkpoint.contributors,sequence=checkpoint.acceptedSteps,physical=checkpoint.physical
                if mode == 0 { sequence+=1 }
                if mode == 1 { records.removeAll(where:{$0.id == owner.schema.id}) }
                if mode == 2 {
                    let index=try #require(records.firstIndex(where:{$0.id == owner.schema.id})),record=records[index]
                    var bytes=record.bytes;bytes[bytes.count-8]=2
                    records[index]=try RuntimeContributorState(id:record.id,category:record.category,version:record.version,bytes:bytes)
                }
                if mode == 3 { physical=try KinematicState(revision:1,time:physical.time,q:[-2,-2],v:physical.v,acceleration:physical.acceleration) }
                let bad=try RuntimeCheckpoint(model:checkpoint.model,continuation:checkpoint.continuation,physical:physical,contributors:records,random:checkpoint.random,acceptedSteps:sequence)
                #expect(throws:LoadedSleepAdmissionFailure.self) { _=try handler.admitWithLoadReport(bad,model:model,configuration:LoadedSleepFixtures.configuration(fresh)) }
            }
            let fresh=try LoadedSleepFixtures.owner(model,dwell:0),handler=LoadedSleepRuntimeCheckpointHandler(sleep:fresh,revisions:ReferenceModelRevisionUpdater())
            let small=try LoadedSleepFixtures.configuration(fresh,validationWork:owner.schema.maximumBytes)
            do throws(LoadedSleepAdmissionFailure) {
                _=try handler.admitWithLoadReport(checkpoint,model:model,configuration:small)
                Issue.record("Cold proof unexpectedly fit byte-only validation capacity.")
            } catch { #expect(error.loads.invocationsStarted == 0) }
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
