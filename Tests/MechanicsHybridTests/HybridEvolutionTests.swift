import SwiftMechanics
import Testing

@Suite("Hybrid reintegrated directed events")
struct HybridEvolutionTests {
    @Test func bounceUsesActualIntegrationRootImpulseAndContinuation() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let (session,evolution,history,smooth,token,work)=try HybridFixtures.setup()
        defer { session.shutdown() }
        let source=session.snapshot(), service:any HybridEvolving=evolution
        let result=try service.advance(session,to:0.6,work:work,cancellation:token)
        let hit=(0.2).squareRoot(), rebound=5*hit, dt=0.6-hit
        #expect(result.impacts.count == 1); #expect(abs(result.impacts[0].timeSeconds-hit) < 1e-9)
        #expect(abs(result.accepted.checkpoint.physical.q[0]-(0.5+rebound*dt-5*dt*dt)) < 1e-7)
        #expect(abs(result.accepted.checkpoint.physical.v[0]-(rebound-10*dt)) < 1e-7)
        #expect(result.accepted.checkpoint.random == source.checkpoint.random)
        #expect(result.accepted.checkpoint.acceptedSteps == 2); #expect(result.work.acceptedSegments == 2)
        #expect(result.work.queries > 20); #expect(result.work.trajectoryDerivativeCalls > 0)
        let eventRecord=try #require(result.accepted.checkpoint.contributors.first(where: { $0.id == history.schema.id }))
        let value=try history.associatedHistory(eventRecord,physical:result.accepted.checkpoint.physical)
        #expect(value.impactGroups == 1); #expect(value.lastEventIDs == [10])
        let smoothRecord=try #require(result.accepted.checkpoint.contributors.first(where: { $0.id == smooth.schema.id }))
        #expect(try smooth.history(smoothRecord).acceptedSteps == 2)
    }
    @Test func restartPreservesEventOrderingAndBounceTrajectory() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let (a,evolution,history,_,token,work)=try HybridFixtures.setup()
        let (b,other,_,_,otherToken,otherWork)=try HybridFixtures.setup()
        defer { a.shutdown(); b.shutdown() }
        _=try evolution.advance(a,to:0.6,work:work,cancellation:token)
        let codec:any RuntimeCheckpointCoding=NativeRuntimeCheckpointCodec(), bytes=try a.checkpoint(codec:codec)
        _=try b.restart(bytes,codec:codec)
        let left=try evolution.advance(a,to:0.92,work:work,cancellation:token)
        let right=try other.advance(b,to:0.92,work:otherWork,cancellation:otherToken)
        #expect(left.accepted == right.accepted); #expect(left.impacts.count == 1)
        let hit=(0.2).squareRoot(); #expect(abs(left.impacts[0].timeSeconds-2*hit) < 2e-9)
        let record=try #require(left.accepted.checkpoint.contributors.first(where: { $0.id == history.schema.id }))
        #expect(try history.history(record).impactGroups == 2)
    }
    @Test func failedCascadeRetainsLastAcceptedImpactPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let (session,evolution,history,_,token,work)=try HybridFixtures.setup(events:1)
        defer { session.shutdown() }
        do { _=try evolution.advance(session,to:0.92,work:work,cancellation:token); Issue.record("Expected event capacity failure.") }
        catch {
            if case .capacityExceeded=error.cause {} else { Issue.record("Unexpected failure.") }
            let prefix=error.lastAccepted
            #expect(prefix == session.snapshot()); #expect(abs(prefix.checkpoint.physical.time-(0.2).squareRoot()) < 1e-9)
            #expect(prefix.checkpoint.physical.v[0] > 0); #expect(prefix.checkpoint.acceptedSteps == 1)
            let record=try #require(prefix.checkpoint.contributors.first(where: { $0.id == history.schema.id }))
            #expect(try history.history(record).impactGroups == 1); #expect(error.work.acceptedImpacts == 1)
        }
    }
    @Test func cancellationAndQueryExhaustionLeaveAllAcceptedStateUnchanged() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let (session,evolution,_,_,token,work)=try HybridFixtures.setup(queries:1)
        defer { session.shutdown() }; let source=session.snapshot()
        do { _=try evolution.advance(session,to:0.6,work:work,cancellation:token); Issue.record("Expected query bound.") }
        catch { #expect(error.lastAccepted == source); #expect(error.work.queries == 1) }
        token.cancel()
        do { _=try evolution.advance(session,to:0.6,work:work,cancellation:token); Issue.record("Expected cancellation.") }
        catch { if case .cancelled=error.cause {} else { Issue.record("Expected typed cancellation.") }; #expect(error.lastAccepted == source) }
        #expect(session.snapshot() == source)
    }
    @Test func truncatedContributorAndCheckpointAreTransactionalFailures() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let (session,_,history,_,_,_)=try HybridFixtures.setup(); defer { session.shutdown() }
        let source=session.snapshot(), record=try #require(source.checkpoint.contributors.first(where: { $0.id == history.schema.id }))
        let corrupt=try RuntimeContributorState(id:record.id,category:record.category,version:record.version,bytes:Array(record.bytes.dropLast()))
        do { _=try session.performTrial { (trial: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision in
            try trial.setPosition(2,at:0); _=try trial.nextRandom(); try trial.replaceContributor(corrupt); return .accept
        }; Issue.record("Expected invalid continuation failure.") } catch { #expect(error.code == .invalidContributor) }
        #expect(session.snapshot() == source)
        let codec:any RuntimeCheckpointCoding=NativeRuntimeCheckpointCodec(), bytes=try session.checkpoint(codec:codec)
        do { _=try session.restart(Array(bytes.dropLast()),codec:codec); Issue.record("Expected truncated checkpoint failure.") } catch { #expect(error.code == .truncatedCheckpoint) }
        #expect(session.snapshot() == source)
    }
    @Test func plasticBounceStopsWithActualAcceptedPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let (session,evolution,_,_,token,work)=try HybridFixtures.setup(e:0); defer { session.shutdown() }
        do { _=try evolution.advance(session,to:0.6,work:work,cancellation:token); Issue.record("Expected unsupported resting support.") }
        catch {
            if case .unsupportedDomain=error.cause {} else { Issue.record("Expected resting-domain failure.") }
            #expect(abs(error.lastAccepted.checkpoint.physical.time-(0.2).squareRoot()) < 1e-9)
            #expect(abs(error.lastAccepted.checkpoint.physical.v[0]) < 1e-8); #expect(error.work.acceptedImpacts == 1)
        }
    }
}
