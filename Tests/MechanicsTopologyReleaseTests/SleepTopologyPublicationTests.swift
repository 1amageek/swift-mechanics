import SwiftMechanics
import Testing

@Suite struct SleepTopologyPublicationTests {
    @Test func realReleaseWakesPublishesGlobalHistoryAndMovesUnderRetainedDrive() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() };_=try SleepTopologyFixtures.enter(source)
        let before=source.session.snapshot(),selection=try SleepTopologyFixtures.select(source),publisher=ReferenceSleepTopologyTransitionPreparer()
        #expect(source.session.snapshot() == before)
        let target=selection.transition.release.target,b=try #require(target.tree.layout.joints.first {$0.joint.key == "b"}),c=try #require(target.tree.layout.joints.first {$0.joint.key == "c"})
        let free=try #require(target.tree.layout.joints.first {$0.joint == selection.transition.release.connector})
        #expect(free.positions.count == 7);#expect(free.velocities.count == 6)
        #expect(selection.transition.motion.rowIDs == [12])
        #expect(abs(selection.transition.physical.acceleration[b.velocities.start]+1) < 1e-9)
        #expect(abs(selection.transition.physical.acceleration[c.velocities.start]+1) < 1e-9)
        #expect(abs(selection.transition.motion.generalizedReaction[b.velocities.start]-2) < 1e-9)
        #expect(abs(selection.transition.motion.generalizedReaction[c.velocities.start]+2) < 1e-9)
        for i in free.velocities.start..<(free.velocities.start+6) { #expect(abs(selection.transition.physical.acceleration[i]) < 1e-9) }
        let accepted=try publisher.publish(selection.prepared,session:source.session)
        #expect(accepted.checkpoint.acceptedSteps == before.checkpoint.acceptedSteps+1)
        #expect(accepted.checkpoint.random == before.checkpoint.random)
        #expect(accepted.checkpoint.physical.time.bitPattern == before.checkpoint.physical.time.bitPattern)
        #expect(selection.prepared.handler.history.events == [selection.wake.event])
        #expect(accepted.checkpoint.contributors.contains(selection.wake.record))
        #expect(!accepted.checkpoint.contributors.contains {$0.id == source.owner.schema.id})
        let stored=try selection.continuation.history(#require(accepted.checkpoint.contributors.first {$0.id == selection.continuation.schema.id}))
        #expect(stored.acceptedSteps == accepted.checkpoint.acceptedSteps);#expect(stored.acceptedPoint == accepted.checkpoint.physical.q+accepted.checkpoint.physical.v)
        let h=0.05,result=try ProjectedNonlinearMechanismEvolution().advance(source.session,equations:selection.equations,continuation:selection.continuation,to:accepted.checkpoint.physical.time+h)
        #expect(result.work.derivativeCalls > 0);#expect(result.work.supplierArithmeticCharged > 0)
        let physical=result.accepted.checkpoint.physical
        for joint in [b,c] {
            #expect(abs(physical.q[joint.positions.start]+h*h/2) < 1e-9)
            #expect(abs(physical.v[joint.velocities.start]+h) < 1e-9)
        }
        let prefix=source.session.snapshot(),bytes=try source.session.checkpoint(codec:NativeRuntimeCheckpointCodec()),budget=try SleepTopologyFixtures.work().budget,equations=selection.equations
        _=try source.session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
            var work=NumericalWork(budget:budget),point=[Double](repeating:0,count:equations.descriptor.dimensions.count)
            try equations.read(trial,into:&point)
            let actual=try equations.consistent(time:trial.timeSeconds,point:point,work:&work,control:control)
            #expect(abs(actual.kineticEnergy-2*h*h) < 1e-9)
            #expect(abs(-4*physical.q[b.positions.start]-actual.kineticEnergy) < 1e-9)
            #expect(abs(actual.acceleration.generalizedReaction[b.velocities.start]*physical.v[b.velocities.start]+actual.acceleration.generalizedReaction[c.velocities.start]*physical.v[c.velocities.start]) < 1e-9)
            _=try trial.nextRandom();try trial.setPosition(1,at:b.positions.start);return .reject
        }
        #expect(source.session.snapshot() == prefix);#expect(try source.session.checkpoint(codec:NativeRuntimeCheckpointCodec()) == bytes)
        #expect(throws:TopologyReleaseFailure.self) { try publisher.publish(selection.prepared,session:source.session) }
        #expect(source.session.snapshot() == prefix)
    }
    @Test func freshOriginalSourceColdProofReissuesAndRestoresExactTargetReplay() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() };_=try SleepTopologyFixtures.enter(source)
        let oldBytes=try source.session.checkpoint(codec:NativeRuntimeCheckpointCodec()),selected=try SleepTopologyFixtures.select(source)
        _=try ReferenceSleepTopologyTransitionPreparer().publish(selected.prepared,session:source.session)
        let t=source.session.snapshot().checkpoint.physical.time
        _=try ProjectedNonlinearMechanismEvolution().advance(source.session,equations:selected.equations,continuation:selected.continuation,to:t+0.02)
        let saved=try source.session.checkpoint(codec:NativeRuntimeCheckpointCodec())
        let final=try ProjectedNonlinearMechanismEvolution().advance(source.session,equations:selected.equations,continuation:selected.continuation,to:t+0.04).accepted
        let finalBytes=try source.session.checkpoint(codec:NativeRuntimeCheckpointCodec())
        let freshSource=try SleepTopologyFixtures.source();defer { freshSource.session.shutdown() }
        #expect(freshSource.session.snapshot().checkpoint.acceptedSteps == 0)
        _=try freshSource.session.restart(oldBytes,codec:NativeRuntimeCheckpointCodec())
        let fresh=try SleepTopologyFixtures.select(freshSource),cold=try SleepTopologyFixtures.cold(fresh);defer { cold.shutdown() }
        #expect(fresh.retirement !== selected.retirement);#expect(fresh.equations !== selected.equations)
        #expect(fresh.wake.record == selected.wake.record)
        _=try cold.restart(saved,codec:NativeRuntimeCheckpointCodec())
        #expect(try ProjectedNonlinearMechanismEvolution().advance(cold,equations:fresh.equations,continuation:fresh.continuation,to:t+0.04).accepted == final)
        #expect(try cold.checkpoint(codec:NativeRuntimeCheckpointCodec()) == finalBytes)
    }
    @Test(arguments:[0,1,2,3,4]) func coldRefusesAccelerationGlobalSequenceMissingWakeAndCorruptWake(_ fault:Int) throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() };_=try SleepTopologyFixtures.enter(source)
        let selected=try SleepTopologyFixtures.select(source),accepted=try ReferenceSleepTopologyTransitionPreparer().publish(selected.prepared,session:source.session)
        let cold=try SleepTopologyFixtures.cold(selected);defer { cold.shutdown() };let prefix=cold.snapshot(),checkpoint=accepted.checkpoint
        var records=checkpoint.contributors,physical=checkpoint.physical,steps=checkpoint.acceptedSteps
        if fault == 0 { physical=try KinematicState(revision:physical.revision,time:physical.time,q:physical.q,v:physical.v,acceleration:[Double](repeating:0,count:physical.v.count)) }
        if fault == 1 { steps += 1 }
        if fault == 2 { records.removeAll {$0.id == selected.wake.schema.id} }
        if fault == 3 || fault == 4 {
            let i=try #require(records.firstIndex {$0.id == selected.wake.schema.id});var bytes=records[i].bytes
            if fault == 3 { bytes[bytes.count-1] ^= 1 } else { bytes.append(0) }
            records[i]=try RuntimeContributorState(id:records[i].id,category:records[i].category,version:records[i].version,bytes:bytes)
        }
        let forged=try RuntimeCheckpoint(model:checkpoint.model,continuation:checkpoint.continuation,physical:physical,contributors:records,random:checkpoint.random,acceptedSteps:steps)
        #expect(throws:RuntimeFailure.self) { try cold.restart(NativeRuntimeCheckpointCodec().encode(forged,capacity:cold.configuration.capacity),codec:NativeRuntimeCheckpointCodec()) }
        #expect(cold.snapshot() == prefix);#expect(cold.snapshot().checkpoint.random == prefix.checkpoint.random)
    }
    @Test(arguments:[0,1,2]) func targetPreparationRefusesMissingDuplicateAndUnboundDispositionAtomically(_ fault:Int) throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() };_=try SleepTopologyFixtures.enter(source)
        let selected=try SleepTopologyFixtures.select(source),before=source.session.snapshot()
        let dispositions:[SleepTopologyContributorDisposition]=fault == 0 ? [] : fault == 1 ? [.appendHistory,.appendHistory,.initializeGlobalIntegration(retiredID:source.owner.continuation.schema.id)] : [.appendHistory,.retireSleep,.initializeGlobalIntegration(retiredID:"unknown")]
        var work=try SleepTopologyFixtures.work();try work.chargeOperations(7)
        #expect(throws:TopologyReleaseFailure.self) {
            try ReferenceSleepTopologyTransitionPreparer().prepare(source:before,sourceConfiguration:source.session.configuration,retirement:selected.retirement,
                transition:selected.transition,history:source.history,observation:.explicit(selected.transition.release),ruleID:1,dispositions:dispositions,
                targetConfiguration:selected.prepared.configuration,equations:selected.equations,continuation:selected.continuation,validationBudget:work.budget,cancellation:nil,work:&work)
        }
        #expect(work.operations >= 7);#expect(source.session.snapshot() == before)
    }
    @Test(arguments:[0,1]) func freshChangedMassOrPolicyCannotRestoreOldSourceWakeCatalog(_ fault:Int) throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() };_=try SleepTopologyFixtures.enter(source)
        let selected=try SleepTopologyFixtures.select(source);_=try ReferenceSleepTopologyTransitionPreparer().publish(selected.prepared,session:source.session)
        let bytes=try source.session.checkpoint(codec:NativeRuntimeCheckpointCodec())
        let other=try SleepTopologyFixtures.source(mass:fault == 0 ? 3 : 2,energy:fault == 1 ? 2 : 1);defer { other.session.shutdown() };_=try SleepTopologyFixtures.enter(other)
        let changed=try SleepTopologyFixtures.select(other,energy:fault == 1 ? 2 : 1),cold=try SleepTopologyFixtures.cold(changed);defer { cold.shutdown() }
        let prefix=cold.snapshot()
        #expect(throws:RuntimeFailure.self) { try cold.restart(bytes,codec:NativeRuntimeCheckpointCodec()) }
        #expect(cold.snapshot() == prefix)
    }
}
