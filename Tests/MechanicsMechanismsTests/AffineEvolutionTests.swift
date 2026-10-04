import SwiftMechanics
import Testing

@Suite struct AffineEvolutionTests {
    @Test func torqueDrivenCompiledGearsAndCheckpointReplay() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(),equation=try MechanismFixtures.equation(model)
            let (session,continuation)=try MechanismFixtures.session(model,equation:equation)
            defer { _=session.shutdown() }
            let integrator=ReferenceExplicitIntegrator()
            let half=try integrator.advance(session,model:model,equations:equation,continuation:continuation,to:0.5)
            #expect(abs(half.accepted.checkpoint.physical.q[0]-0.25) < 1e-9)
            #expect(abs(half.accepted.checkpoint.physical.q[1]+0.125) < 1e-9)
            let bytes=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            let full=try integrator.advance(session,model:model,equations:equation,continuation:continuation,to:1)
            let state=full.accepted.checkpoint.physical
            #expect(abs(state.q[0]-1) < 1e-9);#expect(abs(state.q[1]+0.5) < 1e-9)
            #expect(abs(state.v[0]-2) < 1e-9);#expect(abs(state.v[1]+1) < 1e-9)
            #expect(abs(state.q[0]+2*state.q[1]) < 1e-9);#expect(abs(state.v[0]+2*state.v[1]) < 1e-9)
            _=try session.restart(bytes,codec:NativeRuntimeCheckpointCodec())
            let replay=try integrator.advance(session,model:model,equations:equation,continuation:continuation,to:1)
            #expect(replay.accepted == full.accepted)
            #expect(full.work.supplierArithmeticCharged > 0)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func actualAdaptiveRejectHistoryPreservesAffineInvariant() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(),equation=try MechanismFixtures.equation(model)
            let (session,continuation)=try MechanismFixtures.session(model,equation:equation,adaptive:true);defer { _=session.shutdown() }
            let result=try ReferenceExplicitIntegrator().advance(session,model:model,equations:equation,continuation:continuation,to:0.1)
            #expect(result.rejectedTrials > 0)
            #expect(abs(result.accepted.checkpoint.physical.q[0]-0.01) < 1e-9)
            #expect(abs(result.accepted.checkpoint.physical.v[0]-0.2) < 1e-9)
            let record=try #require(result.accepted.checkpoint.contributors.first)
            let history=try continuation.associatedHistory(record,physical:result.accepted.checkpoint.physical,equations:equation)
            #expect(history.acceptedSteps == UInt64(result.acceptedSteps));#expect(history.acceptedTime == 0.1)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func inconsistentPhysicalInitialStateFailsWithoutProjection() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(q:[1,0]),equation=try MechanismFixtures.equation(model)
            let (session,continuation)=try MechanismFixtures.session(model,equation:equation);defer { _=session.shutdown() }
            let before=session.snapshot()
            do throws(IntegrationFailure) { _=try ReferenceExplicitIntegrator().advance(session,model:model,equations:equation,continuation:continuation,to:0.1);Issue.record("Inconsistent DAE input accepted.") }
            catch { #expect(error.lastAccepted == before) }
            #expect(session.snapshot() == before)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
