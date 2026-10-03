import Testing
import MechanicsCompiler
import MechanicsRuntime
import MechanicsIntegration

@Suite struct IntegrationContinuationTests {
    @Test func rejectedActuationAndRandomUpdatesRollbackAndRestartContinuesExactly() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let model = try IntegrationFixtures.model(), eq = try ManufacturedHingeEquation(model: model,prepareSubsystem: true)
        let policy = try IntegrationFixtures.policy(method: .heunEuler,step: 0.5,tolerance: 1e-5)
        let (session,c) = try IntegrationFixtures.session(model: model,equation: eq,policy: policy)
        let service: any ExplicitIntegrating = ReferenceExplicitIntegrator()
        let one = try service.step(session,model: model,equations: eq,continuation: c)
        #expect(one.acceptedSteps == 1 && one.rejectedTrials > 0 && !one.reachedRequestedTime)
        #expect(one.accepted.checkpoint.random.draws == 1)
        #expect(one.accepted.checkpoint.contributors.first(where: { $0.id == "actuation-counter" })!.bytes == [1])
        let bytes = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        let (restarted,c2) = try IntegrationFixtures.session(model: model,equation: eq,policy: policy)
        _ = try restarted.restart(bytes,codec: NativeRuntimeCheckpointCodec())
        for _ in 0..<6 {
            _ = try service.step(session,model: model,equations: eq,continuation: c)
            _ = try service.step(restarted,model: model,equations: eq,continuation: c2)
        }
        #expect(session.snapshot() == restarted.snapshot())
        #expect(try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) == restarted.checkpoint(codec: NativeRuntimeCheckpointCodec()))
    }
    @Test func corruptedOptionsAssociationAndMissingHistoryFailExplicitly() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let model = try IntegrationFixtures.model(), eq = try ManufacturedHingeEquation(model: model)
        let policy = try IntegrationFixtures.policy(), (session,c) = try IntegrationFixtures.session(model: model,equation: eq,policy: policy)
        let old = session.snapshot(), record = old.checkpoint.contributors.first(where: { $0.id == c.schema.id })!
        var bytes = record.bytes; bytes[0] ^= 1
        do throws(RuntimeFailure) { _ = try c.history(RuntimeContributorState(id: record.id,category: record.category,version: record.version,bytes: bytes)); Issue.record("Corrupt signature succeeded.") }
        catch { #expect(error.code == .incompatibleContinuation) }
        let other = try IntegrationContinuationProvider(descriptor: eq.descriptor,policy: IntegrationFixtures.policy(step: 0.2))
        do throws(RuntimeFailure) { _ = try other.history(record); Issue.record("Changed options succeeded.") }
        catch { #expect(error.code == .incompatibleContinuation) }
        _ = try session.performTrial { (trial: inout RuntimeTrial,control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try trial.setPosition(2,at: 0); return .accept
        }
        let prefix = session.snapshot()
        let failed = try #require(IntegrationFixtures.failure(.invalidContributor) { () throws(IntegrationFailure) in
            _ = try ReferenceExplicitIntegrator().advance(session,model: model,equations: eq,continuation: c,to: 1)
        }); #expect(failed.lastAccepted == prefix && session.snapshot() == prefix)
        let handler = try IntegrationFixtures.Handler(contributors: IntegrationTestContributors(integration: c),revisions: ReferenceModelRevisionUpdater())
        let counter = try IntegrationTestContributors.counter()
        do throws(RuntimeFailure) {
            _ = try IntegrationFixtures.Session(model: model,configuration: session.configuration,initialState: model.descriptor.initialState,
                contributors: [counter],seed: 7,checkpoints: handler)
            Issue.record("Missing history accepted.")
        } catch { #expect(error.code == .missingContributor) }
    }
}
