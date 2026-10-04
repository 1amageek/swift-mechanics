import SwiftMechanics
import Testing

@Suite struct SleepTopologyRetirementTests {
    @Test func actualConstrainedEquilibriumSleepsOmitsAndIssuesMappedRetirement() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() }
        let (active,omitted)=try SleepTopologyFixtures.enter(source),accepted=source.session.snapshot()
        let record=try #require(accepted.checkpoint.contributors.first {$0.id == source.owner.schema.id})
        let history=try source.owner.history(record)
        #expect(history.asleep == [true,true,true]);#expect(history.drive == [4,-4,0])
        #expect(accepted.checkpoint.physical.q == [0,0,0]);#expect(accepted.checkpoint.physical.v == [0,0,0])
        #expect(accepted.checkpoint.physical.acceleration == [0,0,0]);#expect(accepted.checkpoint.acceptedSteps == 3)
        #expect(active > omitted);#expect(omitted > 0)
        let selected=try SleepTopologyFixtures.select(source),retirement=selected.retirement
        #expect(source.session.snapshot() == accepted);#expect(retirement.source == accepted)
        #expect(retirement.retiredConstraintIDs == [11]);#expect(retirement.retiredEffort == 4)
        #expect(retirement.targetConstraints.rows.map(\.id) == [12]);#expect(!retirement.sourceLawSignature.isEmpty)
        let layout=selected.transition.release.target.tree.layout
        for joint in layout.joints {
            let values=Array(retirement.targetDrive[joint.velocities.start..<(joint.velocities.start+joint.velocities.count)])
            #expect(values == (joint.joint.key == "b" ? [-4] : [Double](repeating:0,count:joint.velocities.count)))
        }
    }
    @Test(arguments:[[],[12],[11,12],[11,11]]) func incompleteOrWrongLawDispositionCannotRetire(_ retired:[UInt64]) throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() };_=try SleepTopologyFixtures.enter(source)
        let accepted=source.session.snapshot(),release=try SleepTopologyFixtures.release(source),equation=try SleepTopologyFixtures.equation(release.target,target:true)
        var work=try SleepTopologyFixtures.work();try work.chargeOperations(17)
        do {
            _=try source.owner.prepareRetirement(source:accepted,sourceConfiguration:source.session.configuration,checkpoints:source.handler,
                release:release,retiredConstraintIDs:retired,targetConstraints:SleepTopologyFixtures.retained(equation),targetVelocityLayout:equation.velocityLayout,cancellation:nil,work:&work)
            Issue.record("An incomplete or changed source law was retired.")
        } catch let failure as SleepTopologyFailure {
            #expect(failure.lastAccepted == accepted);#expect(failure.knownWork == work);#expect(work.operations > 17)
        }
        #expect(source.session.snapshot() == accepted)
    }
    @Test func injectedContextCannotWaiveOriginalAwakeSourceProof() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() }
        let accepted=source.session.snapshot(),release=try SleepTopologyFixtures.release(source),equation=try SleepTopologyFixtures.equation(release.target,target:true)
        let permissive=SleepTopologyPassThroughHandler(accepted);var work=try SleepTopologyFixtures.work()
        #expect(throws:SleepTopologyFailure.self) {
            try source.owner.prepareRetirement(source:accepted,sourceConfiguration:source.session.configuration,checkpoints:permissive,
                release:release,retiredConstraintIDs:[11],targetConstraints:SleepTopologyFixtures.retained(equation),targetVelocityLayout:equation.velocityLayout,cancellation:nil,work:&work)
        }
        #expect(permissive.calls() == 0);#expect(source.session.snapshot() == accepted)
        var exhausted=try SleepTopologyFixtures.work(operations:0)
        #expect(throws:SleepTopologyFailure.self) {
            try source.owner.prepareRetirement(source:accepted,sourceConfiguration:source.session.configuration,checkpoints:permissive,
                release:release,retiredConstraintIDs:[11],targetConstraints:SleepTopologyFixtures.retained(equation),targetVelocityLayout:equation.velocityLayout,cancellation:nil,work:&exhausted)
        }
        #expect(permissive.calls() == 0)
    }
    @Test(arguments:[0,1,2]) func completeSourceRejectsSequenceTimeAndExactPositionHistoryMismatch(_ fault:Int) throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let source=try SleepTopologyFixtures.source();defer { source.session.shutdown() };_=try SleepTopologyFixtures.enter(source)
        let accepted=source.session.snapshot(),checkpoint=accepted.checkpoint,codec=NativeRuntimeCheckpointCodec()
        var records=checkpoint.contributors
        let index=try #require(records.firstIndex {$0.id == source.owner.continuation.schema.id})
        let history=try source.owner.continuation.history(records[index]);var point=history.acceptedPoint
        if fault == 2 { point[0] = -0.0 }
        records[index]=try source.owner.continuation.record(acceptedTime:fault == 1 ? history.acceptedTime+0.1 : history.acceptedTime,
            point:point,nextStep:history.nextStep,acceptedSteps:fault == 0 ? history.acceptedSteps+1 : history.acceptedSteps,normalizedError:nil)
        let forged=try RuntimeCheckpoint(model:checkpoint.model,continuation:checkpoint.continuation,physical:checkpoint.physical,
            contributors:records,random:checkpoint.random,acceptedSteps:checkpoint.acceptedSteps)
        #expect(throws:RuntimeFailure.self) { try source.session.restart(codec.encode(forged,capacity:source.session.configuration.capacity),codec:codec) }
        #expect(source.session.snapshot() == accepted);#expect(source.session.snapshot().checkpoint.random == checkpoint.random)
    }
    @Test func newRetirementSignatureBindsChangedSameIdentityMassAndPolicy() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let original=try SleepTopologyFixtures.source(),mass=try SleepTopologyFixtures.source(mass:3),policy=try SleepTopologyFixtures.source(energy:2)
        defer { original.session.shutdown();mass.session.shutdown();policy.session.shutdown() }
        for source in [original,mass,policy] { _=try SleepTopologyFixtures.enter(source) }
        let a=try SleepTopologyFixtures.select(original),b=try SleepTopologyFixtures.select(mass),c=try SleepTopologyFixtures.select(policy,energy:2)
        #expect(original.model.stamp == mass.model.stamp);#expect(original.model.tree.layout == mass.model.tree.layout)
        #expect(a.retirement.sourceLawSignature != b.retirement.sourceLawSignature)
        #expect(a.retirement.sourceLawSignature != c.retirement.sourceLawSignature)
    }
}
