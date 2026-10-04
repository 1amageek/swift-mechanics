import SwiftMechanics
import Testing

@Suite struct QuadraticColdTests {
    @Test(.timeLimit(.minutes(1))) func actualRetainedRowsReconcileInsteadOfFreeForwardForce() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try QuadraticColdFixture(),release=try fixture.release(),equation=try QuadraticColdFixture.equation(release.target,target:true)
            var work=try QuadraticColdFixture.work()
            let preparer:any NonlinearSubtreeAccelerationPreparing=ReferenceNonlinearSubtreeAccelerationPreparer()
            let result=try preparer.prepare(release:release,equations:equation,work:&work)
            let b=try #require(release.target.tree.layout.joints.first(where:{$0.joint.key == "b"})),c=try #require(release.target.tree.layout.joints.first(where:{$0.joint.key == "c"})),a=try #require(release.target.tree.layout.joints.first(where:{$0.joint.key == "free-a"}))
            #expect(result.descriptor == equation.descriptor);#expect(result.motion.temporalMeaning == .accelerationForce)
            #expect(result.motion.rowIDs == [2]);#expect(result.motion.basis == release.target.tree.layout)
            #expect(result.physical.q.map(\.bitPattern) == release.incomingPhysical.q.map(\.bitPattern))
            #expect(result.physical.v.map(\.bitPattern) == release.incomingPhysical.v.map(\.bitPattern))
            #expect(result.physical.time.bitPattern == release.incomingPhysical.time.bitPattern);#expect(result.physical.revision == release.target.stamp.revision)
            #expect(a.positions.count == 7 && a.velocities.count == 6)
            #expect(result.physical.acceleration[a.velocities.range].allSatisfy { abs($0) < 1e-10 })
            #expect(abs(result.physical.acceleration[b.velocities.start]+1) < 1e-10)
            #expect(abs(result.physical.acceleration[c.velocities.start]+1) < 1e-10)
            #expect(abs(result.motion.generalizedReaction[b.velocities.start]-2) < 1e-10)
            #expect(abs(result.motion.generalizedReaction[c.velocities.start]+2) < 1e-10)
            let snapshot=try release.target.evaluate(release.target.makeState(result.physical))
            #expect(abs(try snapshot.body(QuadraticColdFixture.id(.body,"b")).motion.acceleration.linear.y+1) < 1e-10)
            #expect(abs(try snapshot.body(QuadraticColdFixture.id(.body,"c")).motion.acceleration.linear.y+1) < 1e-10)
            let (session,_)=try QuadraticColdFixture.session(equation,initial:result.physical);defer { _=session.shutdown() }
            #expect(session.snapshot().checkpoint.acceptedSteps == 0)
            var freeWork=try QuadraticColdFixture.work(),load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0))
            let free=try ReferenceSubtreeAccelerationPreparer().prepare(release,gravity:nil,bodyWrenches:[],generalizedForces:[],drive:equation.drive,
                admission:QuadraticColdFixture.admission(),policy:equation.policy.dynamics,work:&freeWork,loadWork:&load)
            #expect(abs(free.physical.acceleration[b.velocities.start]+2) < 1e-10);#expect(abs(free.physical.acceleration[c.velocities.start]) < 1e-10)
            do { let (invalid,_)=try QuadraticColdFixture.session(equation,initial:free.physical);_=invalid.shutdown();Issue.record("Free force admitted as retained-row force") }
            catch { #expect(error is RuntimeFailure) }
        }
    }
    @Test(.timeLimit(.minutes(1))) func physicalSignatureRejectsSameRevisionChangedMassAndLegacyAuthority() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let original=try QuadraticColdFixture(),changed=try QuadraticColdFixture(changedMass:3)
            let equation=try QuadraticColdFixture.equation(original.model),other=try QuadraticColdFixture.equation(changed.model)
            let legacy=try QuadraticColdFixture.equation(original.model,strict:false),legacyChanged=try QuadraticColdFixture.equation(changed.model,strict:false)
            #expect(original.model.stamp == changed.model.stamp);#expect(legacy.descriptor == legacyChanged.descriptor)
            #expect(equation.descriptor != other.descriptor)
            let (source,_)=try QuadraticColdFixture.session(equation);defer { _=source.shutdown() }
            let (target,_)=try QuadraticColdFixture.session(other);defer { _=target.shutdown() }
            let codec=NativeRuntimeCheckpointCodec(),before=try target.checkpoint(codec:codec),saved=try source.checkpoint(codec:codec)
            do throws(RuntimeFailure) { _=try target.restart(saved,codec:codec);Issue.record("Changed mass accepted old source history") }
            catch { #expect(error.code == .incompatibleContinuation) }
            #expect(try target.checkpoint(codec:codec) == before)
            do { let (invalid,_)=try QuadraticColdFixture.session(legacy);_=invalid.shutdown();Issue.record("Legacy polynomial chart claimed cold source authority") }
            catch { #expect(error is RuntimeFailure) }
        }
    }
    @Test(.timeLimit(.minutes(1))) func constrainedTargetAdvancesAndFreshOwnerReplaysExactCheckpoint() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let release=try QuadraticColdFixture().release(),equation=try QuadraticColdFixture.equation(release.target,target:true)
            var work=try QuadraticColdFixture.work()
            let physical=try ReferenceNonlinearSubtreeAccelerationPreparer().prepare(release:release,equations:equation,work:&work).physical
            let (session,continuation)=try QuadraticColdFixture.session(equation,initial:physical);defer { _=session.shutdown() }
            let evolution=ProjectedNonlinearMechanismEvolution(),codec=NativeRuntimeCheckpointCodec()
            _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.05)
            let saved=try session.checkpoint(codec:codec)
            let final=try evolution.advance(session,equations:equation,continuation:continuation,to:0.1).accepted
            for key in ["b","c"] {
                let entry=try #require(release.target.tree.layout.joints.first(where:{$0.joint.key == key}))
                #expect(abs(final.checkpoint.physical.q[entry.positions.start]+0.005) < 1e-10)
                #expect(abs(final.checkpoint.physical.v[entry.velocities.start]+0.1) < 1e-10)
                #expect(abs(final.checkpoint.physical.acceleration[entry.velocities.start]+1) < 1e-10)
            }
            let record=try #require(final.checkpoint.contributors.first),history=try continuation.associatedHistory(record,physical:final.checkpoint.physical,equations:equation)
            #expect(history.acceptedSteps == final.checkpoint.acceptedSteps)
            _=try session.restart(saved,codec:codec)
            #expect(try evolution.advance(session,equations:equation,continuation:continuation,to:0.1).accepted == final)
            let coldEquation=try QuadraticColdFixture.equation(release.target,target:true)
            let (fresh,freshContinuation)=try QuadraticColdFixture.session(coldEquation,initial:physical);defer { _=fresh.shutdown() }
            _=try fresh.restart(saved,codec:codec)
            #expect(try evolution.advance(fresh,equations:coldEquation,continuation:freshContinuation,to:0.1).accepted == final)
            #expect(try fresh.checkpoint(codec:codec) == session.checkpoint(codec:codec))
        }
    }
    @Test(.timeLimit(.minutes(1))) func forgedForceTimePointSequenceAndCatalogPreserveWholePrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let equation=try QuadraticColdFixture.equation(QuadraticColdFixture().model)
            let (session,continuation)=try QuadraticColdFixture.session(equation);defer { _=session.shutdown() }
            let old=session.snapshot().checkpoint,codec=NativeRuntimeCheckpointCodec(),before=try session.checkpoint(codec:codec)
            for fault in 0..<8 {
                var physical=old.physical,records=old.contributors
                switch fault {
                case 0: physical=try KinematicState(revision:1,time:0,q:physical.q,v:physical.v,acceleration:[0.1,0.1,0.1])
                case 1: physical=try KinematicState(revision:1,time:0.1,q:physical.q,v:physical.v,acceleration:physical.acceleration)
                case 2: physical=try KinematicState(revision:1,time:0,q:[0.1,0.1,0.1],v:physical.v,acceleration:physical.acceleration)
                case 3: records=[try continuation.record(acceptedTime:0,point:physical.q+physical.v,nextStep:0.01,acceptedSteps:1,normalizedError:nil)]
                case 4: records=[]
                case 5: records=old.contributors+old.contributors
                case 6:
                    var point=physical.q+physical.v;point[0] = -0.0
                    records=[try continuation.record(acceptedTime:0,point:point,nextStep:0.01,acceptedSteps:0,normalizedError:nil)]
                default: records=[try RuntimeContributorState(id:"unknown-law",category:.actuator,version:1,bytes:[1])]+old.contributors
                }
                do throws(RuntimeFailure) {
                    let altered=try RuntimeCheckpoint(model:old.model,continuation:old.continuation,physical:physical,contributors:records,random:old.random,acceptedSteps:old.acceptedSteps)
                    _=try session.restart(codec.encode(altered,capacity:session.configuration.capacity),codec:codec)
                    Issue.record("Forged quadratic checkpoint admitted")
                } catch { #expect(error.code != .cancelled) }
                #expect(try session.checkpoint(codec:codec) == before);#expect(session.snapshot().checkpoint.random == old.random)
            }
            do throws(RuntimeFailure) {
                _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    _=try trial.nextRandom()
                    for i in 0..<3 { try trial.setAcceleration(0.1,at:i) }
                    try trial.replaceContributor(continuation.record(acceptedTime:0,point:old.physical.q+old.physical.v,nextStep:0.01,acceptedSteps:1,normalizedError:nil))
                    return .accept
                }
                Issue.record("Row-consistent force-wrong trial published")
            } catch { #expect(error.code == .invalidState) }
            #expect(try session.checkpoint(codec:codec) == before)
            _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                _=try trial.nextRandom();return .reject
            }
            #expect(try session.checkpoint(codec:codec) == before)
        }
    }
    @Test(.timeLimit(.minutes(1))) func requiredOriginalActuatorCatalogIsValidatedBeforeColdRuntimeAcceptance() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try QuadraticColdFixture(),equation=try QuadraticColdFixture.equation(fixture.model)
            let (temporary,continuation)=try QuadraticColdFixture.session(equation)
            let capacity=temporary.configuration.capacity,identity=temporary.configuration.continuation;_=temporary.shutdown()
            let range=try #require(fixture.model.tree.layout.joints.first(where:{$0.joint.key == "b"}))
            func binding(_ revision:UInt64) throws -> ActuatorBinding {
                try ActuatorBinding(actuator:QuadraticColdFixture.id(.actuator,"b-law"),joint:range.joint,frame:fixture.model.descriptor.worldFrame,
                    model:fixture.model.stamp,lawRevision:revision,continuationKey:7,positionIndex:range.positions.start,velocityIndex:range.velocities.start,
                    coordinate:.translation,authority:.dynamicState,stateKind:.servo,stateDomain:ActuatorScalarDomain(primaryLower:-10,primaryUpper:10,secondaryLower:-10,secondaryUpper:10))
            }
            let budget=try ActuationBudget(maximumWork:100000,maximumScalars:10000,maximumBytes:10000,maximumBindings:16,maximumMetadataBytes:10000)
            var actuation=ActuationWork(budget:budget)
            let original=try binding(1),codec=FixedActuatorContinuationCodec()
            let actuator=try ActuatorRuntimeContributors(bindings:[original],codec:codec,controlBudget:budget,work:&actuation)
            let law=try codec.encode(ActuatorState(binding:original,time:0,primary:0.4,secondary:-0.2,mode:.position,sequence:8),work:&actuation)
            let registry=try TopologyRuntimeContributors(providers:[continuation,actuator],capacity:capacity)
            let configuration=try RuntimeConfiguration(continuation:identity,requiredContributors:registry.schemas,capacity:capacity,determinism:.sameBuildReplay,workload:"quadratic-required-law")
            let base=ReferenceRuntimeCheckpointHandler(contributors:registry,revisions:ReferenceModelRevisionUpdater())
            let handler=try NonlinearMechanismCheckpointHandler(equations:equation,continuation:continuation,base:base,validationBudget:QuadraticColdFixture.work().budget)
            let initial=fixture.model.descriptor.initialState
            let session=try QuadraticColdFixture.Session(model:fixture.model,configuration:configuration,initialState:initial,
                contributors:[continuation.initialRecord(physical:initial,equations:equation),law],seed:42,checkpoints:handler);defer { _=session.shutdown() }
            let native=NativeRuntimeCheckpointCodec(),before=try session.checkpoint(codec:native),old=session.snapshot().checkpoint
            let changedLaw=try codec.encode(ActuatorState(binding:binding(2),time:0,primary:0.4,secondary:-0.2,mode:.position,sequence:8),work:&actuation)
            for records in [old.contributors.filter {$0.id != law.id},old.contributors.map {$0.id == law.id ? changedLaw : $0}] {
                do throws(RuntimeFailure) {
                    let checkpoint=try RuntimeCheckpoint(model:old.model,continuation:old.continuation,physical:old.physical,contributors:records,random:old.random,acceptedSteps:old.acceptedSteps)
                    _=try session.restart(native.encode(checkpoint,capacity:capacity),codec:native);Issue.record("Missing or changed original law source admitted")
                } catch { #expect(error.code == .missingContributor || error.code == .invalidContributor) }
                #expect(try session.checkpoint(codec:native) == before)
            }
        }
    }
}
