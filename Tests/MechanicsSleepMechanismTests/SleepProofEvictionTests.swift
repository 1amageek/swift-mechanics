@testable import SwiftMechanics
import Testing

@Suite struct SleepProofEvictionTests {
    @Test func independentSessionCannotEvictPreparedSleepingAuthority() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try SleepFixtures.model(),owner=try SleepFixtures.owner(model,dwell:0)
            let first=try SleepFixtures.session(model,owner:owner)
            let otherPhysical=try KinematicState(revision:model.stamp.revision,time:0,q:[1,-0.5],v:[0,0],acceleration:[0,0])
            let second=try SleepFixtures.session(model,owner:owner,physical:otherPhysical)
            defer { _=first.shutdown();_=second.shutdown() }
            _=try owner.step(first)
            let source=first.snapshot(),history=try SleepFixtures.history(owner,source)
            #expect(history.asleep == [true,true])
            let adapter=try SleepMechanismEquation(owner:owner,source:source,history:history)
            let interleaved=SleepProofEvictingEquation(base:adapter,owner:owner,other:second)
            let result=try ReferenceExplicitIntegrator().step(first,model:model,equations:interleaved,continuation:owner.continuation)
            // The other actual session prepares/accepts a different equilibrium between this prepare and its first stage.
            #expect(second.snapshot().checkpoint.physical.q == [1,-0.5])
            #expect(second.snapshot().checkpoint.acceptedSteps == 1)
            #expect(result.accepted.checkpoint.physical.q == [0,0])
            #expect(result.accepted.checkpoint.physical.v == [0,0])
            #expect(result.accepted.checkpoint.physical.acceleration == [0,0])
            #expect(try SleepFixtures.history(owner,result.accepted).asleep == [true,true])
            #expect(result.accepted.checkpoint.acceptedSteps == source.checkpoint.acceptedSteps+1)
            #expect(result.accepted.checkpoint.random == source.checkpoint.random)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
