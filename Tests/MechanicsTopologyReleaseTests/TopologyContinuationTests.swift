import SwiftMechanics
import Testing

@Suite struct TopologyContinuationTests {
    @Test func twoSameTimeCutsReplayFromOldRevisionAndRestoreIntoColdFinalOwner() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let model=try TopologyFixtures.model(),(session,history,binding)=try TopologyFixtures.session(model,integrator:true)
        let publisher=ReferenceTopologyTransitionPreparer(),before=session.snapshot()
        let first=try TopologyFixtures.prepare(session,history:history,binding:binding,rule:history.catalog.rules[0],integrator:true)
        _=try publisher.publish(first,session:session)
        let migration=try #require(first.actuatorMigrations.first)
        #expect(migration.target.primary == migration.source.primary)
        #expect(migration.target.secondary == migration.source.secondary)
        #expect(migration.target.sequence == 8)
        #expect(migration.target.binding.model == first.transition.release.target.stamp)
        #expect(migration.target.binding.positionIndex != migration.source.binding.positionIndex)
        var work=ActuationWork(budget:try TopologyFixtures.actuationBudget()),numerical=try TopologyFixtures.work()
        let state=migration.target,b=state.binding
        let law=try ScalarServo(binding:b,positionGain:2,velocityGain:1,integralGain:0.5,integralLimit:10,effortLimit:100,speedLimit:100,
            positionDeadband:0,velocityDeadband:0,filterTimeConstant:0.2)
        let sample=try ActuatorSample(binding:b,time:state.time,position:first.transition.physical.q[b.positionIndex],velocity:first.transition.physical.v[b.velocityIndex])
        let response=try ReferenceDriveEvaluator().step(law:law,state:state,sample:sample,command:DriveCommand(mode:.position,value:1),dt:0.1,
            energyTolerance:TopologyFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(response.state.sequence == state.sequence+1)
        #expect(response.state.time == 0.1)
        #expect(response.state.primary != state.primary)
        #expect(try FixedActuatorContinuationCodec().decode(FixedActuatorContinuationCodec().encode(response.state,work:&work),binding:b,work:&work) == response.state)

        let second=try TopologyFixtures.prepare(session,history:first.handler.history,binding:b,rule:history.catalog.rules[1],integrator:true)
        let final=try publisher.publish(second,session:session),saved=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
        #expect(second.handler.history.events.map(\.id) == [1,2])
        #expect(second.handler.history.events.map(\.acceptedTime) == [0,0])
        #expect(second.handler.history.events.map(\.acceptedSequence) == [1,2])
        #expect(final.checkpoint.random == before.checkpoint.random)
        #expect(final.checkpoint.acceptedSteps == 2)
        let restoredHistory=try TopologyHistoryContributor(model:second.transition.release.target,catalog:history.catalog,policy:history.policy,record:second.handler.history.record)
        #expect(restoredHistory.events == second.handler.history.events)
        let (replay,replayHistory,replayBinding)=try TopologyFixtures.session(model,integrator:true)
        let replayFirst=try TopologyFixtures.prepare(replay,history:replayHistory,binding:replayBinding,rule:history.catalog.rules[0],integrator:true)
        _=try publisher.publish(replayFirst,session:replay)
        let replaySecond=try TopologyFixtures.prepare(replay,history:replayFirst.handler.history,binding:replayFirst.actuatorMigrations[0].target.binding,rule:history.catalog.rules[1],integrator:true)
        _=try publisher.publish(replaySecond,session:replay)
        #expect(try replay.checkpoint(codec:NativeRuntimeCheckpointCodec()) == saved)
        #expect(throws:RuntimeFailure.self) {
            try TopologyFixtures.Session(model:second.transition.release.target,configuration:second.configuration,initialState:second.transition.physical,
                contributors:second.contributors,seed:42,checkpoints:second.handler)
        }
        let target=second.transition.release.target
        let catalog=try TopologyEventCatalog(initialModel:target.stamp,initialTime:0,initialSequence:0,rules:history.catalog.rules,policy:history.policy)
        let bootstrap=try TopologyHistoryContributor(model:target,catalog:catalog,policy:history.policy)
        let providers=second.handler.contributors.providers.filter { $0.schemas != restoredHistory.schemas }+[bootstrap]
        let registry=try TopologyRuntimeContributors(providers:providers,capacity:second.configuration.capacity)
        let handler=try TopologyCheckpointHandler(history:restoredHistory,contributors:second.handler.contributors,
            bootstrap:bootstrap,physical:target.makeState(second.transition.physical),bootstrapContributors:registry)
        let records=second.contributors.filter { $0.id != bootstrap.schema.id }+[bootstrap.record]
        let cold=try TopologyFixtures.Session(model:target,configuration:second.configuration,initialState:second.transition.physical,contributors:records,seed:42,checkpoints:handler)
        let bootstrapCheckpoint=cold.snapshot().checkpoint
        let advanced=try RuntimeCheckpoint(model:bootstrapCheckpoint.model,continuation:bootstrapCheckpoint.continuation,physical:bootstrapCheckpoint.physical,
            contributors:bootstrapCheckpoint.contributors,random:bootstrapCheckpoint.random,acceptedSteps:1)
        #expect(throws:RuntimeFailure.self) { try handler.admit(advanced,model:target,configuration:second.configuration,cancellation:nil) }
        #expect(try cold.restart(saved,codec:NativeRuntimeCheckpointCodec()).checkpoint == final.checkpoint)
        #expect(try cold.restart(saved,codec:NativeRuntimeCheckpointCodec()).checkpoint == final.checkpoint)
        #expect(try cold.checkpoint(codec:NativeRuntimeCheckpointCodec()) == saved)
        #expect(throws:RuntimeFailure.self) { try handler.admit(advanced,model:target,configuration:second.configuration,cancellation:nil) }
    }
    @Test func duplicateStaleOmittedAndBoundedHistoryFailuresPreserveWholePrefix() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let model=try TopologyFixtures.model(),(session,history,binding)=try TopologyFixtures.session(model)
        let rule=history.catalog.rules[0],prepared=try TopologyFixtures.prepare(session,history:history,binding:binding,rule:rule)
        let initial=session.snapshot(),publisher=ReferenceTopologyTransitionPreparer()
        var w=try TopologyFixtures.work(),a=ActuationWork(budget:try TopologyFixtures.actuationBudget())
        #expect(throws:TopologyReleaseFailure.self) {
            try publisher.prepare(source:initial,sourceConfiguration:session.configuration,transition:prepared.transition,history:history,
                observation:.explicit(prepared.transition.release),ruleID:rule.id,dispositions:[.appendHistory],targetConfiguration:prepared.configuration,work:&w,actuationWork:&a)
        }
        #expect(session.snapshot() == initial)
        #expect(throws:TopologyReleaseFailure.self) {
            try publisher.prepare(source:initial,sourceConfiguration:session.configuration,transition:prepared.transition,history:history,
                observation:.explicit(prepared.transition.release),ruleID:rule.id,
                dispositions:[.appendHistory,.preserve(id:binding.actuator.key,validator:prepared.actuatorMigrations[0].provider)],
                targetConfiguration:prepared.configuration,work:&w,actuationWork:&a)
        }
        #expect(session.snapshot() == initial)
        var bytes=prepared.handler.history.record.bytes;bytes.append(0)
        let malformed=try RuntimeContributorState(id:history.schema.id,category:.event,version:1,bytes:bytes)
        #expect(throws:TopologyReleaseFailure.self) {
            try TopologyHistoryContributor(model:prepared.transition.release.target,catalog:history.catalog,policy:history.policy,record:malformed)
        }
        let tiny=try TopologyFixtures.historyPolicy(events:2,bytes:16)
        #expect(throws:TopologyReleaseFailure.self) { try TopologyHistoryContributor(model:model,catalog:history.catalog,policy:tiny) }
        #expect(session.snapshot() == initial)
        _=try publisher.publish(prepared,session:session)
        let accepted=session.snapshot()
        #expect(throws:TopologyReleaseFailure.self) { try publisher.publish(prepared,session:session) }
        #expect(throws:TopologyReleaseFailure.self) {
            try prepared.handler.history.appending(source:initial,target:prepared.transition,observation:.explicit(prepared.transition.release),ruleID:rule.id)
        }
        #expect(session.snapshot() == accepted)
        #expect(accepted.checkpoint.random == initial.checkpoint.random)
    }
    @Test func removedActuatorCannotBeSilentlyReset() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let model=try TopologyFixtures.model(),(session,history,binding)=try TopologyFixtures.session(model)
        let rule=try TopologyFixtures.rule(1,joint:"j3",root:"C",connector:"removed-servo")
        let release=try TopologyFixtures.release(model,rule:rule),record=try #require(session.snapshot().checkpoint.contributors.first(where: { $0.category == .actuator }))
        var work=ActuationWork(budget:try TopologyFixtures.actuationBudget())
        #expect(throws:TopologyReleaseFailure.self) {
            try ScalarActuatorTopologyMigration.prepare(record:record,binding:binding,release:release,controlBudget:TopologyFixtures.actuationBudget(),work:&work)
        }
        #expect(session.snapshot().checkpoint.acceptedSteps == 0)
        #expect(session.snapshot().checkpoint.contributors.contains(history.record))
    }
    @Test func actualReplacementRejectsChangedTargetCapacityAndProfileWithoutPublishing() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let model=try TopologyFixtures.model(),(session,history,binding)=try TopologyFixtures.session(model)
        let prepared=try TopologyFixtures.prepare(session,history:history,binding:binding,rule:history.catalog.rules[0])
        let initial=session.snapshot(),configuration=session.configuration,c=prepared.configuration.capacity
        let changedCapacity=try RuntimeCapacity(maximumPhysicalScalars:c.maximumPhysicalScalars,maximumContributors:c.maximumContributors,
            maximumContributorBytes:c.maximumContributorBytes,maximumMetadataBytes:c.maximumMetadataBytes,maximumCheckpointBytes:c.maximumCheckpointBytes,
            maximumValidationWork:c.maximumValidationWork,maximumValidationScratchBytes:c.maximumValidationScratchBytes,
            maximumObservationLeases:c.maximumObservationLeases+1,maximumBatchStates:c.maximumBatchStates,maximumTransactions:c.maximumTransactions,
            maximumStepWorkUnits:c.maximumStepWorkUnits,maximumWorkBetweenSafePoints:c.maximumWorkBetweenSafePoints)
        let capacityConfiguration=try RuntimeConfiguration(continuation:prepared.configuration.continuation,
            requiredContributors:prepared.configuration.requiredContributors,capacity:changedCapacity,
            determinism:prepared.configuration.determinism,workload:prepared.configuration.workload)
        let profileConfiguration=try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"different-build",backend:"reference-cpu",precision:"float64"),
            requiredContributors:prepared.configuration.requiredContributors,capacity:c,
            determinism:prepared.configuration.determinism,workload:prepared.configuration.workload)
        let cases:[(RuntimeConfiguration,RuntimeFailureCode)]=[(capacityConfiguration,.capacityExceeded),(profileConfiguration,.incompatibleContinuation)]
        for (targetConfiguration,expectedFailure) in cases {
            let request=RuntimeModelReplacement(expectedSource:initial.checkpoint,model:prepared.transition.release.target,
                physical:prepared.transition.physical,contributors:prepared.contributors,configuration:targetConfiguration,checkpoints:prepared.handler)
            do throws(RuntimeFailure) {
                _=try session.replaceModel(request)
                Issue.record("Changed owner capacity/profile was published.")
            } catch {
                #expect(error.code == expectedFailure)
                #expect(error.lastAccepted?.checkpoint == initial.checkpoint)
            }
            #expect(session.snapshot() == initial)
            #expect(session.snapshot().checkpoint.random == initial.checkpoint.random)
            #expect(session.configuration == configuration)
        }
    }
}
