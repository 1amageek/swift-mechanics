import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct GranularRuntimeAdmissionTests {
    @Test func changedMassPolicySeedAndCarrierRefuseOriginalJournal() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture();defer { _=f.session.shutdown() };_=try f.advance()
        let old=f.session.snapshot().checkpoint.contributors[0]
        let mass=try GranularRuntimeFixture(mass:2),seed=try GranularRuntimeFixture(seed:456)
        let policy=try GranularRuntimeFixture(policy:GranularRuntimeParticleFixtures.policy(neighbors:1000))
        defer { _=mass.session.shutdown();_=seed.session.shutdown();_=policy.session.shutdown() }
        for changed in [mass,seed,policy] {
            var work=try GranularRuntimeFixture.work(changed.source.physicsBudget)
            do throws(GranularRuntimeError) { _=try changed.journal.decode(old,work:&work);Issue.record("Changed original source accepted") }
            catch { if case .staleSource=error {} else { Issue.record("Wrong changed-source refusal") } }
            #expect(work.workUnits > 0 && work.numerical.operations == 0)
        }
        let wrong=try GranularRuntimeCarrierFixtures.model(revision:2),provider: any RuntimeContributorHandling=GranularRuntimeContributors(journal:f.journal)
        let budget=try RuntimeValidationBudget(workUnits:1000000,scratchBytes:400000)
        do throws(RuntimeFailure) { _=try provider.validate(old,model:wrong,budget:budget);Issue.record("Changed carrier accepted") }
        catch { #expect(error.code == .incompatibleModel) }
    }
    @Test func forgedChoiceTimeSequenceRandomAndMalformedBytesCannotReissueHistory() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture();defer { _=f.session.shutdown() }
        let offset=f.session.snapshot().checkpoint.contributors[0].bytes.count-48;_=try f.advance()
        let record=f.session.snapshot().checkpoint.contributors[0],actual=try f.accepted()
        let changes=[(offset,Double(3).bitPattern),(offset+8,UInt64(2)),(offset+24,UInt64(0)),(offset+32,UInt64(2)),
                     (offset+48,(actual.gravityChoiceIndices[0]+1)%2)]
        for (index,value) in changes {
            let bad=try GranularRuntimeFixture.changed(record,offset:index,value:value)
            var work=try GranularRuntimeFixture.work(f.source.physicsBudget)
            do throws(GranularRuntimeError) { _=try f.journal.decode(bad,work:&work);Issue.record("Forged accepted input/history metadata accepted") }
            catch { if case .malformedJournal=error {} else { Issue.record("Wrong forged journal refusal") } }
            #expect(work.workUnits > 0)
        }
        let truncated=try RuntimeContributorState(id:record.id,category:record.category,version:record.version,bytes:Array(record.bytes.dropLast()))
        var work=try GranularRuntimeFixture.work(f.source.physicsBudget)
        #expect(throws:GranularRuntimeError.self) { _=try f.journal.decode(truncated,work:&work) }
    }
    @Test func wholeCheckpointTimeStepsAndRngMismatchCannotPublishRestart() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture();defer { _=f.session.shutdown() };_=try f.advance()
        let prefix=f.session.snapshot(),old=prefix.checkpoint
        let shifted=try KinematicState(revision:old.physical.revision,time:1,q:[],v:[],acceleration:[])
        let cases=[try RuntimeCheckpoint(model:old.model,continuation:old.continuation,physical:shifted,contributors:old.contributors,random:old.random,acceptedSteps:old.acceptedSteps),
                   try RuntimeCheckpoint(model:old.model,continuation:old.continuation,physical:old.physical,contributors:old.contributors,random:old.random,acceptedSteps:3),
                   try RuntimeCheckpoint(model:old.model,continuation:old.continuation,physical:old.physical,contributors:old.contributors,random:RuntimeRandomState(seed:987),acceptedSteps:old.acceptedSteps)]
        for checkpoint in cases {
            let wire=try NativeRuntimeCheckpointCodec().encode(checkpoint,capacity:f.session.configuration.capacity)
            do throws(RuntimeFailure) { _=try f.session.restart(wire,codec:NativeRuntimeCheckpointCodec());Issue.record("Incoherent whole checkpoint published") }
            catch { #expect(error.code == .invalidState && error.lastAccepted == prefix) }
            #expect(f.session.snapshot() == prefix)
        }
    }
    @Test func exactStepDurationAndAcceptedJournalCapacityPreserveRuntimePrefix() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture(steps:1);defer { _=f.session.shutdown() }
        let initial=f.session.snapshot()
        do throws(RuntimeFailure) { _=try f.advance(duration:0.002);Issue.record("Changed timestep accepted") }
        catch { #expect(error.code == .invalidState && error.lastAccepted == initial) }
        _=try f.advance();let prefix=f.session.snapshot()
        do throws(RuntimeFailure) { _=try f.advance();Issue.record("Unbounded journal advance accepted") }
        catch { #expect(error.code == .invalidState && error.lastAccepted == prefix) }
        #expect(f.session.snapshot() == prefix)
    }
    @Test func byteWorkNativeReplayAndValidationBudgetsAreActualTypedLimits() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture();defer { _=f.session.shutdown() };_=try f.advance()
        let record=f.session.snapshot().checkpoint.contributors[0]
        for (bytes,units) in [(0,1000000),(400000,0),(400000,10000)] {
            var work=try GranularRuntimeFixture.work(f.source.physicsBudget,bytes:bytes,units:units)
            do throws(GranularRuntimeError) { _=try f.journal.decode(record,work:&work);Issue.record("Exhausted replay limit accepted") }
            catch { if case .capacityExceeded=error {} else { Issue.record("Wrong replay budget refusal") } }
            #expect(work.numerical.operations == 0)
        }
        let limited=try GranularRuntimeFixture(numericalOperations:0);defer { _=limited.session.shutdown() }
        let prefix=limited.session.snapshot()
        #expect(throws:RuntimeFailure.self) { _=try limited.advance() }
        #expect(limited.session.snapshot() == prefix)
        let provider: any RuntimeContributorHandling=GranularRuntimeContributors(journal:f.journal)
        let budget=try RuntimeValidationBudget(workUnits:10000,scratchBytes:400000)
        do throws(RuntimeFailure) { _=try provider.validate(record,model:f.model,budget:budget);Issue.record("Validation work limit accepted") }
        catch { #expect(error.code == .contributorBudgetExceeded) }
    }
    @Test func callerNativeBudgetSubstitutionCannotBypassOriginalSourceCeiling() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let limited=try GranularRuntimeFixture(numericalOperations:0);defer { _=limited.session.shutdown() }
        var random=RuntimeRandomState(seed:123);let draw=try random.next()
        let seed=limited.session.snapshot().checkpoint.contributors[0],offset=seed.bytes.count-48
        var payload=seed.bytes
        for i in 0..<8 { payload.append(UInt8(truncatingIfNeeded:(draw%2) >> (8*i))) }
        var record=try RuntimeContributorState(id:seed.id,category:seed.category,version:seed.version,bytes:payload)
        for (index,value) in [(offset,Double(0.001).bitPattern),(offset+8,UInt64(1)),(offset+24,random.state),(offset+32,UInt64(1)),(offset+40,UInt64(1))] {
            record=try GranularRuntimeFixture.changed(record,offset:index,value:value)
        }
        var work=try GranularRuntimeFixture.work(limited.source.physicsBudget)
        work.numerical=try GranularRuntimeParticleFixtures.numerical(operations:500000,storage:10000)
        do throws(GranularRuntimeError) {
            _=try limited.journal.decode(record,work:&work)
            Issue.record("Caller replaced actual native source budget and bypassed zero original operations")
        } catch { if case .staleSource=error {} else { Issue.record("Wrong actual budget-source refusal") } }
        #expect(work.numerical.operations == 0)
    }

}
