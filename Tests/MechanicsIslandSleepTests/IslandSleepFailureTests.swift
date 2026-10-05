import Testing
import SwiftMechanics

@Suite internal struct IslandSleepFailureTests {
    @Test(arguments:[0,1,2,3,4]) func malformedCheckpointRefusesWithoutPublication(_ variant:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let owner=try IslandSleepFixtures.owner(),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() }
        var work=try IslandSleepFixtures.work();_=try owner.step(session,work:&work)
        let original=session.snapshot(),p=original.checkpoint.physical
        var records=original.checkpoint.contributors,physical=p,sequence=original.checkpoint.acceptedSteps
        switch variant {
        case 0:sequence += 1
        case 1:var q=p.q;q[0]=Double.leastNonzeroMagnitude;physical=try KinematicState(revision:p.revision,time:p.time,q:q,v:p.v,acceleration:p.acceleration)
        case 2:var a=p.acceleration;a[0]=1;physical=try KinematicState(revision:p.revision,time:p.time,q:p.q,v:p.v,acceleration:a)
        case 3:records.removeAll(where:{$0.id == owner.schema.id})
        default:
            let index=try #require(records.firstIndex(where:{$0.id == owner.schema.id}));var bytes=records[index].bytes;bytes[bytes.count-1]=255
            records[index]=try RuntimeContributorState(id:owner.schema.id,category:owner.schema.category,version:owner.schema.version,bytes:bytes)
        }
        let bad=try RuntimeCheckpoint(model:original.checkpoint.model,continuation:original.checkpoint.continuation,physical:physical,contributors:records,random:original.checkpoint.random,acceptedSteps:sequence)
        let bytes=try NativeRuntimeCheckpointCodec().encode(bad,capacity:session.configuration.capacity)
        do { _=try session.restart(bytes,codec:NativeRuntimeCheckpointCodec());Issue.record("Malformed full checkpoint was accepted.") }
        catch let error as RuntimeFailure { #expect(error.code == (variant == 3 ? .missingContributor : .invalidContributor)) }
        #expect(session.snapshot() == original)
    }
    @Test(arguments:[0,1,2]) func changedPhysicalLawCannotRestoreOldSleep(_ variant:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let owner=try IslandSleepFixtures.owner(),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() };var work=try IslandSleepFixtures.work();_=try owner.step(session,work:&work)
        let bytes=try session.checkpoint(codec:NativeRuntimeCheckpointCodec()),changed:IslandCheckpointedMechanismSleep
        if variant == 0 { changed=try IslandSleepFixtures.owner(model:IslandSleepMechanicalFixtures.model(time:0,inertia:4)) }
        else if variant == 1 { changed=try IslandSleepFixtures.owner(drive:[2,2,0]) }
        else { changed=try IslandSleepFixtures.owner(dwell:0.2) }
        let fresh=try IslandSleepFixtures.session(changed);defer { _=fresh.shutdown() };let before=fresh.snapshot()
        do { _=try fresh.restart(bytes,codec:NativeRuntimeCheckpointCodec());Issue.record("Changed physical force/inertia/policy restored old sleep.") }
        catch let error as RuntimeFailure { #expect(error.code == .incompatibleContinuation) }
        #expect(fresh.snapshot() == before)
    }
    @Test(arguments:[0,1,2]) func boundedCapacityStopsBeforePhysicalSupplier(_ variant:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let observed=IslandSleepObservedDynamics(),owner=try IslandSleepFixtures.owner(dynamics:observed),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() }
        observed.reset();var work=try IslandSleepFixtures.work(operations:variant == 0 ? 0 : 100000000,storage:variant == 1 ? 0 : 1000000,loads:variant == 2 ? 0 : 1000000)
        let before=session.snapshot()
        do { _=try owner.step(session,work:&work);Issue.record("Exhausted supplier capacity succeeded.") } catch let error as IslandSleepFailure { #expect(error.accepted == before) }
        #expect(observed.restCount == 0);#expect(observed.motionCount(0) == 0);#expect(observed.motionCount(2) == 0);#expect(session.snapshot() == before)
    }
    @Test func participantResetRollsBackWholePhysicalAndRNG() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let participant=try IslandSleepParticipant(),owner=try IslandSleepFixtures.owner(participant:participant),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() }
        var work=try IslandSleepFixtures.work();let before=session.snapshot();participant.breakLedger()
        do { _=try owner.step(session,work:&work);Issue.record("Reset participant succeeded.") } catch let error as IslandSleepFailure { #expect(error.failedSupplierWorkUnavailable);#expect(error.accepted == before) }
        #expect(session.snapshot() == before);#expect(work.physical.numerical.operations > 0);#expect(work.contributorEncoding.operations > 0)
    }
    @Test func queryCountAndCancellationRetainOriginalPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let token=HybridCancellation(),owner=try IslandSleepFixtures.owner(token:token),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() }
        var work=try IslandSleepFixtures.work(token:token);_=try owner.step(session,work:&work);let before=session.snapshot(),known=work.physical.numerical.operations
        token.cancel()
        do { _=try owner.query(from:before,configuration:session.configuration,to:0.25,work:&work);Issue.record("Cancelled mixed query succeeded.") }
        catch let error as IslandSleepFailure { if case .runtime(let cause)=error.reason { #expect(cause.code == .cancelled) } else { Issue.record("Cancellation identity lost.") } }
        #expect(session.snapshot() == before);#expect(work.physical.numerical.operations == known);#expect(work.queries == 0)
    }
    @Test(arguments:[0,1,2]) func supplierResetAndOriginalCancellationPreserveKnownWork(_ mode:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let token=HybridCancellation(),fault=IslandSleepFaultDynamics(mode:mode,token:token),owner=try IslandSleepFixtures.owner(dynamics:fault,token:token),session=try IslandSleepFixtures.session(owner);defer { _=session.shutdown() }
        var work=try IslandSleepFixtures.work(token:token);_=try owner.step(session,work:&work);let before=session.snapshot(),operations=work.physical.numerical.operations,loads=work.physical.loads.consumed
        fault.enable()
        do { _=try owner.step(session,work:&work);Issue.record("Broken supplier succeeded.") }
        catch let error as IslandSleepFailure {
            if case .integration(let actual)=error.reason { #expect(actual.cause.code == (mode == 2 ? .cancelled : .invalidOwnerAccess)) } else { Issue.record("Actual Integration failure was lost.") }
            #expect(error.supplierFailure != nil)
            if mode != 2 { #expect(error.failedSupplierWorkUnavailable) }
        }
        #expect(session.snapshot() == before);#expect(work.physical.numerical.operations > operations);#expect(work.physical.loads.consumed > loads);#expect(work.supplierInvocations > 0)
    }

}
