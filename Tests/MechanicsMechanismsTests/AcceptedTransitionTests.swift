import SwiftMechanics
import Testing

@Suite struct AcceptedTransitionTests {
    @Test func actualAcceptedMovingLockAndReplay() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(v:[3,-1]),equation=try MechanismFixtures.equation(model,lock:true)
            let (session,continuation)=try MechanismFixtures.session(model,equation:equation);defer { _=session.shutdown() }
            let source=session.snapshot(),system=try MechanismFixtures.system(model),sample=try MechanismFixtures.sample(rows:[2,-3]),policy=try MechanismFixtures.policy()
            let original=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            var w=try MechanismFixtures.work(),d=try MechanismFixtures.work(),r=try MechanismFixtures.work(),l=try MechanismFixtures.work()
            let result=try RuntimeMechanismLock().engage(session,expected:source,model:model,system:system,sample:sample,policy:policy,
                equation:equation,continuation:continuation,work:&w,dynamicsWork:&d,rankWork:&r,linearWork:&l)
            #expect(result.accepted.checkpoint.acceptedSteps == source.checkpoint.acceptedSteps+1)
            #expect(result.accepted.checkpoint.physical.time == 0)
            #expect(result.accepted.checkpoint.random == source.checkpoint.random)
            #expect(abs(result.accepted.checkpoint.physical.v[0]-1.0/3) < 1e-9)
            #expect(abs((result.impulse.kineticEnergyChange ?? .infinity)+32.0/3) < 1e-9)
            let record=try #require(result.accepted.checkpoint.contributors.first)
            let history=try continuation.associatedHistory(record,physical:result.accepted.checkpoint.physical,equations:equation)
            #expect(history.acceptedSteps == 0)
            let evolved=try ReferenceExplicitIntegrator().advance(session,model:model,equations:equation,continuation:continuation,to:0.1)
            #expect(abs(evolved.accepted.checkpoint.physical.q[0]-1.0/30) < 1e-9)
            #expect(abs(evolved.accepted.checkpoint.physical.q[1]-1.0/30) < 1e-9)
            _=try session.restart(original,codec:NativeRuntimeCheckpointCodec())
            var w2=try MechanismFixtures.work(),d2=try MechanismFixtures.work(),r2=try MechanismFixtures.work(),l2=try MechanismFixtures.work()
            let replay=try RuntimeMechanismLock().engage(session,expected:session.snapshot(),model:model,system:system,sample:sample,policy:policy,
                equation:equation,continuation:continuation,work:&w2,dynamicsWork:&d2,rankWork:&r2,linearWork:&l2)
            #expect(replay.accepted == result.accepted)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func staleAndCancelledEngagementKeepPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(v:[3,-1]),equation=try MechanismFixtures.equation(model,lock:true)
            let (session,continuation)=try MechanismFixtures.session(model,equation:equation);defer { _=session.shutdown() }
            let source=session.snapshot(),system=try MechanismFixtures.system(model),sample=try MechanismFixtures.sample(rows:[2,-3]),cancelled=try MechanismFixtures.policy(cancelled:true)
            var w=try MechanismFixtures.work(),d=try MechanismFixtures.work(),r=try MechanismFixtures.work(),l=try MechanismFixtures.work()
            do throws(MechanismError) { _=try RuntimeMechanismLock().engage(session,expected:source,model:model,system:system,sample:sample,policy:cancelled,
                equation:equation,continuation:continuation,work:&w,dynamicsWork:&d,rankWork:&r,linearWork:&l);Issue.record("Cancelled engagement succeeded.") }
            catch { if case .cancelled=error {} else { Issue.record("Expected cancellation.") } }
            #expect(session.snapshot() == source)
            _=try session.performTrial { (trial,control) throws(RuntimeFailure) in try control.beginWorkBlock(units:1);try trial.setTime(0);return .accept }
            let current=session.snapshot(),policy=try MechanismFixtures.policy()
            do throws(MechanismError) { _=try RuntimeMechanismLock().engage(session,expected:source,model:model,system:system,sample:sample,policy:policy,
                equation:equation,continuation:continuation,work:&w,dynamicsWork:&d,rankWork:&r,linearWork:&l);Issue.record("Stale engagement source succeeded.") }
            catch { if case .staleBinding=error {} else { Issue.record("Expected stale binding.") } }
            #expect(session.snapshot() == current)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
