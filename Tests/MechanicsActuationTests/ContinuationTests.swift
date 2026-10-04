import SwiftMechanics
import Testing

@Suite struct ContinuationTests {
    @Test func fixedPayloadAllKindsStrictDomainAndStaleIdentity() throws {
        let codec:any ActuatorContinuationCoding=FixedActuatorContinuationCodec()
        var work=try ActuationFixtures.work()
        for kind in [ActuatorStateKind.servo,.motor,.fluid,.muscle] {
            let binding=try ActuationFixtures.binding(kind:kind,coordinate:kind == .fluid || kind == .muscle ? .translation : .rotation)
            let state=try ActuationFixtures.state(binding,time:2,primary:0.5,mode:.effort,sequence:3),record=try codec.encode(state,work:&work)
            #expect(record.bytes.count == 176 && record.category == .actuator && record.version == 1)
            #expect(try codec.decode(record,binding:binding,work:&work) == state)
            #expect(throws:ActuationError.staleBinding) { try codec.decode(record,binding:ActuationFixtures.binding(kind:kind,lawRevision:2),work:&work) }
            let moved=try ActuatorBinding(actuator:binding.actuator,joint:binding.joint,frame:ActuationFixtures.id(.frame,"other"),model:binding.model,lawRevision:binding.lawRevision,continuationKey:binding.continuationKey,
                positionIndex:binding.positionIndex,velocityIndex:binding.velocityIndex,coordinate:binding.coordinate,authority:binding.authority,stateKind:binding.stateKind,stateDomain:binding.stateDomain)
            #expect(throws:ActuationError.staleBinding) { try codec.decode(record,binding:moved,work:&work) }
            var bytes=record.bytes;bytes[18]=1
            let malformed=try RuntimeContributorState(id:record.id,category:record.category,version:record.version,bytes:bytes)
            #expect(throws:ActuationError.invalidInput) { try codec.decode(malformed,binding:binding,work:&work) }
        }
    }
    @Test func actualRuntimeContributorValidationAndEarlyBudget() throws {
        let binding=try ActuationFixtures.binding(),registry=try ActuationFixtures.registry(binding),model=try ActuationFixtures.model()
        var work=try ActuationFixtures.work();let record=try registry.codec.encode(ActuationFixtures.state(binding),work:&work)
        let provider:any RuntimeContributorHandling=registry
        let evidence=try provider.validate(record,model:model,budget:RuntimeValidationBudget(workUnits:1000,scratchBytes:512))
        #expect(evidence.workUnitsUsed > 64 && evidence.scratchBytesUsed == 176)
        do { _=try provider.validate(record,model:model,budget:RuntimeValidationBudget(workUnits:0,scratchBytes:512));Issue.record("Budget zero accepted.") }
        catch let error as RuntimeFailure { #expect(error.code == .contributorBudgetExceeded) }
        do { _=try provider.validate(record,model:ActuationFixtures.model(revision:2),budget:RuntimeValidationBudget(workUnits:1000,scratchBytes:512));Issue.record("Stale model accepted.") }
        catch let error as RuntimeFailure { #expect(error.code == .invalidContributor) }
    }
    @Test func coordinatePreservingActualCompilerMigration() throws {
        let source=try ActuationFixtures.model(),target=try ActuationFixtures.model(revision:2),updater=ReferenceModelRevisionUpdater()
        let transition=try updater.transition(from:source,to:target,policy:.preserveIfKinematicsUnchanged)
        let oldBinding=try ActuationFixtures.binding(),newBinding=try ActuationFixtures.binding(revision:2),registry=try ActuationFixtures.registry(newBinding)
        var work=try ActuationFixtures.work();let old=try ActuationFixtures.state(oldBinding,time:3,primary:1,secondary:2,mode:.velocity,sequence:5)
        let record=try registry.codec.encode(old,work:&work)
        let result=try registry.migrate(record,transition:transition,target:target,budget:RuntimeValidationBudget(workUnits:1000,scratchBytes:512))
        let migrated=try registry.codec.decode(result,binding:newBinding,work:&work)
        #expect(migrated.primary == 1 && migrated.secondary == 2 && migrated.time == 3 && migrated.sequence == 5 && migrated.binding.model.revision == 2)
    }
    @Test func actualRuntimeRejectCheckpointRestoreAndSameContinuation() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime supplier OS baseline unavailable.");return }
        let binding=try ActuationFixtures.binding(),registry=try ActuationFixtures.registry(binding),model=try ActuationFixtures.model(),law=try ActuationFixtures.servo(binding)
        let budget=try ActuationFixtures.budget(),numericalBudget=try NumericalBudget(scalarStorage:100,arithmeticOperations:10000,iterations:0),tolerance=try ActuationFixtures.tolerance()
        let command=try DriveCommand(mode:.velocity,value:0.25),operatorValue:any ActuatorTrialOperating=ReferenceActuatorTrialOperator(codec:registry.codec,drives:ReferenceDriveEvaluator(),registry:registry)
        var work=try ActuationFixtures.work();let payload=try registry.codec.encode(ActuationFixtures.state(binding,mode:.velocity),work:&work)
        let capacity=try RuntimeCapacity(maximumPhysicalScalars:10,maximumContributors:1,maximumContributorBytes:512,maximumMetadataBytes:1000,maximumCheckpointBytes:4096,
            maximumValidationWork:1000,maximumValidationScratchBytes:512,maximumObservationLeases:1,maximumBatchStates:1,maximumTransactions:100,maximumStepWorkUnits:10,maximumWorkBetweenSafePoints:2)
        let config=try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"actuation-v1",backend:"referenceCPU",precision:"float64"),requiredContributors:registry.schemas,capacity:capacity,determinism:.sameBuildReplay,workload:"servo-rollback")
        let handler=ReferenceRuntimeCheckpointHandler(contributors:registry,revisions:ReferenceModelRevisionUpdater())
        let session=try RuntimeSession(model:model,configuration:config,initialState:model.descriptor.initialState,contributors:[payload],seed:42,checkpoints:handler)
        let initial=session.snapshot()
        let foreign=try ActuatorBinding(actuator:binding.actuator,joint:binding.joint,frame:ActuationFixtures.id(.frame,"other"),model:binding.model,lawRevision:binding.lawRevision,continuationKey:binding.continuationKey,
            positionIndex:binding.positionIndex,velocityIndex:binding.velocityIndex,coordinate:binding.coordinate,authority:binding.authority,stateKind:binding.stateKind,stateDomain:binding.stateDomain)
        let foreignLaw=try ActuationFixtures.servo(foreign)
        do {
            _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                var work=ActuationWork(budget:budget),numeric=NumericalWork(budget:numericalBudget)
                _=try operatorValue.servo(law:foreignLaw,command:command,dt:1,tolerance:tolerance,trial:&trial,control:&control,work:&work,numerical:&numeric)
                return .accept
            }
            Issue.record("Foreign full binding was accepted.")
        } catch let failure as RuntimeFailure { #expect(failure.code == .invalidContributor) }
        #expect(session.snapshot() == initial)
        func advance(_ reject:Bool=false) throws -> RuntimeTrialOutcome {
            try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                var work=ActuationWork(budget:budget),numerical=NumericalWork(budget:numericalBudget)
                let response=try operatorValue.servo(law:law,command:command,dt:1,tolerance:tolerance,trial:&trial,control:&control,work:&work,numerical:&numerical)
                try trial.setTime(response.state.time)
                if reject { try trial.setPosition(99,at:0);_=try trial.nextRandom() }
                return reject ? .reject : .accept
            }
        }
        _=try advance();let prefix=session.snapshot(),checkpoint=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
        _=try advance(true);#expect(session.snapshot() == prefix)
        _=try advance();let continued=session.snapshot()
        _=try session.restart(checkpoint,codec:NativeRuntimeCheckpointCodec());#expect(session.snapshot() == prefix)
        _=try advance();#expect(session.snapshot() == continued)
        let final=try registry.codec.decode(continued.checkpoint.contributors[0],binding:binding,work:&work)
        #expect(final.sequence == 2 && final.time == 2 && final.primary == 1)
        _=session.shutdown()
    }
    @Test func restoredTimeMismatchCannotAdvanceAndFullRegistryBindingIsRequired() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime supplier OS baseline unavailable.");return }
        let binding=try ActuationFixtures.binding(),state=try ActuationFixtures.state(binding,time:1),law=try ActuationFixtures.servo(binding)
        var work=try ActuationFixtures.work(),numeric=try ActuationFixtures.numerical()
        #expect(throws:ActuationError.staleTime) { try ReferenceDriveEvaluator().step(law:law,state:state,sample:ActuationFixtures.sample(binding,time:0),command:DriveCommand(mode:.effort,value:1),dt:1,energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numeric) }
        let exhausted=try ActuationFixtures.state(binding,sequence:UInt64.max)
        #expect(throws:ActuationError.sequenceOverflow) { try ReferenceDriveEvaluator().step(law:law,state:exhausted,sample:ActuationFixtures.sample(binding),command:DriveCommand(mode:.effort,value:1),dt:1,energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numeric) }
    }
}
