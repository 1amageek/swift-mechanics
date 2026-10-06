import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SensorAuthorityTests {
    @Test(arguments: [SensorFaultSourcePreparer.Fault.stale, .ledger, .unavailable]) func actualSupplierFaultCannotPublish(_ fault: SensorFaultSourcePreparer.Fault) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let session = try SensorPipelineFixtures.session(sources: SensorFaultSourcePreparer(fault: fault)); defer { session.shutdown() }
        let before = session.snapshot().checkpoint
        do { _ = try SensorPipelineFixtures.advance(session, time: 0.125); Issue.record("Faulted source supplier succeeded.") }
        catch let error as RuntimeFailure {
            #expect(error.code == .invalidContributor)
            #expect(error.failedSupplierWorkUnavailable == (fault == .unavailable))
        }
        #expect(session.snapshot().checkpoint == before)
    }
    @Test func callbackCannotReplaceSensorContributor() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let session = try SensorPipelineFixtures.session(); defer { session.shutdown() }
        let before = session.snapshot().checkpoint
        do {
            _ = try session.performTrial { (trial: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) in
                let old = try trial.contributor(session.definition.schemaID)
                try trial.replaceContributor(RuntimeContributorState(id: old.id, category: old.category, version: old.version, bytes: [0])); return .accept
            }
            Issue.record("External sensor continuation mutation succeeded.")
        } catch let error as RuntimeFailure { #expect(error.code == .invalidContributor) }
        #expect(session.snapshot().checkpoint == before)
    }
    @Test func inheritedObserveStillReadsPrefixDuringTrial() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let session = try SensorPipelineFixtures.session(); defer { session.shutdown() }
        let before = session.snapshot().checkpoint
        _ = try session.performTrial { (trial: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) in
            try trial.setTime(0.125); try trial.setPosition(1, at: 0)
            try session.observe { accepted in #expect(accepted.checkpoint == before) }
            return .accept
        }
        #expect(session.snapshot().physical.state.q == [1])
    }
    @Test func unknownEventDomainIsTypedRefused() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let basic = try SensorPipelineFixtures.definition()
        let events = try SensorPipelineDefinition(schemaID: basic.schemaID, world: basic.world, rootSeed: basic.rootSeed, worldKey: basic.worldKey,
            initialTimeSeconds: 0, originSeconds: 0, periodSeconds: 0.125, emitInitial: false, sampling: .linearObservationComponents,
            readyOverflow: .refuseOverflow, channels: basic.channels, bounds: basic.bounds, rawPolicy: basic.rawPolicy,
            eventContributorIDs: ["unqualified.event.history"])
        do { _ = try SensorPipelineFixtures.session(definition: events); Issue.record("Unknown event domain succeeded.") }
        catch let error as SensorPipelineFailure { if case .unsupportedDomain = error {} else { Issue.record("Wrong event refusal.") } }
    }
    @Test func schemaRequestAndActionDimensionsRefuse() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let session = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(emitInitial: true)); defer { session.shutdown() }
        let bad = try SensorBatchReadRequest(schema: "other", version: 1, world: session.definition.world, model: session.snapshot().physical.stamp,
            after: 0, maximumRows: 1, maximumScalars: 1)
        do { try session.readBatch(bad) { _ in Issue.record("Incompatible schema callback ran.") }; Issue.record("Incompatible schema succeeded.") }
        catch let error as SensorPipelineFailure { if case .incompatibleSchema = error {} else { Issue.record("Wrong schema failure.") } }
        let batch = try SensorBatchCapture().capture(session)
        #expect(throws: SensorPipelineFailure.self) { try batch.requireCompatible(schema: batch.schema, version: batch.version, channelIDs: ["position"], dimensions: [.length]) }
    }
}
