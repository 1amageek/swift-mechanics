import SwiftMechanics
import Testing

@Suite struct SleepCriteriaTests {
    @Test func actualMassEnergyAndNormalizedVelocityThresholdsHaveIndependentOracles() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try SleepFixtures.model(v:[2,-1]),system=try SleepFixtures.system(model),sample=try SleepFixtures.sample()
            #expect(system.massMatrix == [2,0,0,4])
            var work=try SleepFixtures.work()
            let exact=try ConnectedMechanismSleep().evaluate(system,sample:sample,wakeCoordinateIDs:[],policy:MechanismSleepPolicy(maximumCoordinates:8,
                kineticEnergyThreshold:6,normalizedVelocityThreshold:5),work:&work)
            #expect(exact.groups == [[10,20]]);#expect(exact.kineticEnergy == [6]);#expect(exact.asleep == [true])
            let energy=try ConnectedMechanismSleep().evaluate(system,sample:sample,wakeCoordinateIDs:[],policy:MechanismSleepPolicy(maximumCoordinates:8,
                kineticEnergyThreshold:5.99,normalizedVelocityThreshold:5),work:&work)
            #expect(energy.asleep == [false])
            let speed=try ConnectedMechanismSleep().evaluate(system,sample:sample,wakeCoordinateIDs:[],policy:MechanismSleepPolicy(maximumCoordinates:8,
                kineticEnergyThreshold:6,normalizedVelocityThreshold:4.99),work:&work)
            #expect(speed.asleep == [false])
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func restoredSleepingAuthorityRevalidatesActualPhysicsWithFreshOwner() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try SleepFixtures.model(),owner=try SleepFixtures.owner(model,dwell:0),session=try SleepFixtures.session(model,owner:owner)
            defer { _=session.shutdown() };_=try owner.step(session)
            let checkpoint=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            let original=try owner.step(session)
            let restoredOwner=try SleepFixtures.owner(model,dwell:0),restored=try SleepFixtures.session(model,owner:restoredOwner)
            defer { _=restored.shutdown() }
            _=try restored.restart(checkpoint,codec:NativeRuntimeCheckpointCodec())
            #expect(try restoredOwner.step(restored).accepted == original.accepted)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
