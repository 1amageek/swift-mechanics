@testable import SwiftMechanics
import Testing

@Suite struct LoadedSleepProofEvictionTests {
    @Test func independentDifferentPositionSessionCannotEvictLoadedPreparedAuthority() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try LoadedSleepFixtures.model(),owner=try LoadedSleepFixtures.owner(model,dwell:0,zeroLoads:true)
            let first=try LoadedSleepFixtures.session(model,owner:owner)
            let second=try LoadedSleepFixtures.session(model,owner:owner,physical:KinematicState(revision:1,time:0,q:[-2,-2],v:[0,0],acceleration:[0,0]))
            defer { _=first.shutdown();_=second.shutdown() }
            _=try owner.stepWithLoads(first,loadBudget:LoadedSleepFixtures.budget(),maximumLoadInvocations:64)
            let source=first.snapshot(),history=try LoadedSleepFixtures.history(owner,source)
            let execution=try StationaryLoadExecution(scope:.equationExecution,budget:LoadedSleepFixtures.budget(work:0),maximumInvocations:0,requiredScalars:2)
            let adapter=try LoadedSleepMechanismEquation(owner:owner,source:source,history:history,execution:execution)
            let interleaved=LoadedSleepProofEvictingEquation(base:adapter,owner:owner,other:second,loadBudget:try LoadedSleepFixtures.budget())
            let result=try ReferenceExplicitIntegrator().step(first,model:model,equations:interleaved,continuation:owner.continuation)
            #expect(second.snapshot().checkpoint.physical.q == [-2,-2]);#expect(second.snapshot().checkpoint.acceptedSteps == 1)
            #expect(result.accepted.checkpoint.physical.q == [-1,-1]);#expect(result.accepted.checkpoint.physical.v == [0,0])
            #expect(try LoadedSleepFixtures.history(owner,result.accepted).mechanics.asleep == [true,true])
            #expect(result.accepted.checkpoint.random == source.checkpoint.random)
            #expect(execution.close().consumed == 0)
            #expect(owner.catalog.dependencyCoordinateIDs == [10,20])
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
