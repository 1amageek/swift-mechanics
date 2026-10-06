import Testing
import SwiftMechanics
@Suite internal struct ConstrainedSleepFailureTests {
    @Test(arguments:[0,1,2,3]) func capacityRefusesWithoutPublication(mode:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let f=try ConstrainedSleepFixtures(maximumEvents:mode == 0 ? 0 : 4,queries:mode == 1 ? 1 : 128,iterations:mode == 2 ? 1 : 64);defer { _=f.session.shutdown() };try f.enterSleep()
        let source=f.session.snapshot(),bytes=try f.session.checkpoint(codec:NativeRuntimeCheckpointCodec())
        let attemptedWork=try f.work(collisionOperations:mode == 3 ? 0 : 10000000)
        do throws(ConstrainedSleepEvolutionFailure) { _=try f.service.advanceToNextImpact(f.session,through:0.4,work:attemptedWork,cancellation:f.token);Issue.record("Capacity admitted an event.") }
        catch { #expect(error.accepted == source);#expect(!error.work.failedSupplierWorkUnavailable);if mode == 3 { #expect(error.work.collision.operations == 0) } }
        #expect(f.session.snapshot() == source);#expect(try f.session.checkpoint(codec:NativeRuntimeCheckpointCodec()) == bytes)
    }
    @Test(arguments:[false,true]) func collisionResetKeepsKnownQuantumAndOriginalFailure(failing:Bool) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let f=try ConstrainedSleepFixtures(collisionQueries:ConstrainedSleepFaultCollision(failing:failing));defer { _=f.session.shutdown() };try f.enterSleep();let source=f.session.snapshot()
        let attemptedWork=try f.work()
        do throws(ConstrainedSleepEvolutionFailure) { _=try f.service.advanceToNextImpact(f.session,through:0.4,work:attemptedWork,cancellation:f.token);Issue.record("Reset collision supplier accepted.") }
        catch { #expect(error.work.failedSupplierWorkUnavailable);#expect(error.work.collision.operations == 1);#expect(error.work.collision.peakScalarStorage == 1);#expect(error.accepted == source)
            if case .supplierLedgerFailure(let original)=error.cause { #expect((original != nil) == failing) } else { Issue.record("Reset lacked typed ledger refusal.") }
        }
        #expect(f.session.snapshot() == source)
    }
    @Test(arguments:[0,1,2]) func realImpulseFailureOrResetRetainsAcceptedPrefix(mode:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let f=try ConstrainedSleepFixtures(impulses:ConstrainedSleepFaultSolver(mode:mode));defer { _=f.session.shutdown() };try f.enterSleep();let source=f.session.snapshot()
        let attemptedWork=try f.work()
        do throws(ConstrainedSleepEvolutionFailure) { _=try f.service.advanceToNextImpact(f.session,through:0.4,work:attemptedWork,cancellation:f.token);Issue.record("Fault impulse published.") }
        catch { #expect(error.accepted == source);#expect(error.work.failedSupplierWorkUnavailable == (mode == 0));#expect(error.work.numerical.operations>0 && error.work.loads.consumed>0)
            if mode>0 { if case .impact(let original)=error.cause { if mode == 2 { if case .hybrid(.cancelled)=original.reason {} else { Issue.record("Original cancellation missing.") } } } else { Issue.record("Original impulse failure missing.") } }
        }
        #expect(f.session.snapshot() == source)
    }
    @Test(arguments:[false,true]) func attemptedWholeWritesRollBackOnAdmissionOrRejection(reject:Bool) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let f=try ConstrainedSleepFixtures();defer { _=f.session.shutdown() };try f.enterSleep();let source=f.session.snapshot(),bytes=try f.session.checkpoint(codec:NativeRuntimeCheckpointCodec()),before=f.session.profile()
        let session=ConstrainedSleepFaultSession(base:f.session,schema:f.events.schema,reject:reject)
        let attemptedWork=try f.work()
        do throws(ConstrainedSleepEvolutionFailure) { _=try f.service.advanceToNextImpact(session,through:0.4,work:attemptedWork,cancellation:f.token);Issue.record("Failed trial published.") }
        catch { #expect(error.accepted == source);#expect(error.work.acceptedImpacts == 0 && error.work.acceptedSegments == 0);if case .runtime=error.cause {} else { Issue.record("Actual Runtime failure missing.") } }
        #expect(f.session.profile().attemptedTransactions == before.attemptedTransactions+1);#expect(f.session.snapshot() == source);#expect(try f.session.checkpoint(codec:NativeRuntimeCheckpointCodec()) == bytes)
    }
    @Test func originalCancellationBeforeQueryAndOnceOnlyEventRetainPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let f=try ConstrainedSleepFixtures();defer { _=f.session.shutdown() };try f.enterSleep();let source=f.session.snapshot();f.token.cancel()
        let attemptedWork=try f.work()
        do throws(ConstrainedSleepEvolutionFailure) { _=try f.service.advanceToNextImpact(f.session,through:0.4,work:attemptedWork,cancellation:f.token);Issue.record("Cancelled event advanced.") }
        catch { if case .hybrid(.cancelled)=error.cause {} else { Issue.record("Wrong cancellation.") };#expect(error.work.queries == 0);#expect(error.accepted == source) }
        #expect(f.session.snapshot() == source)
    }
    @Test(arguments:[0,1,2]) func alteredCatalogOrSequenceRefusesColdRestart(variant:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let f=try ConstrainedSleepFixtures();defer { _=f.session.shutdown() };try f.enterSleep();let codec=NativeRuntimeCheckpointCodec()
        if variant<2 {
            let bytes=try f.session.checkpoint(codec:codec),changed=try ConstrainedSleepFixtures(restitution:variant == 0 ? 0 : 1,geometryOffset:variant == 1 ? 1.1 : 1);defer { _=changed.session.shutdown() };let prefix=changed.session.snapshot()
            do { _=try changed.session.restart(bytes,codec:codec);Issue.record("Changed catalog/law restored.") }
            catch { #expect(error.code == .invalidContributor) };#expect(changed.session.snapshot() == prefix)
        } else {
            let original=f.session.snapshot().checkpoint,changed=try RuntimeCheckpoint(model:original.model,continuation:original.continuation,physical:original.physical,contributors:original.contributors,random:original.random,acceptedSteps:original.acceptedSteps+1),bytes=try codec.encode(changed,capacity:f.session.configuration.capacity)
            do { _=try f.session.restart(bytes,codec:codec);Issue.record("Changed global sequence restored.") } catch { #expect(error.code == .invalidContributor) };#expect(f.session.snapshot().checkpoint == original)
        }
    }
}
