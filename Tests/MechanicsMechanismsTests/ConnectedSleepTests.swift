import SwiftMechanics
import Testing

@Suite struct ConnectedSleepTests {
    @Test func realMassAndGearConnectedWake() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let system=try MechanismFixtures.system(MechanismFixtures.model()),sample=try MechanismFixtures.sample()
            var work=try MechanismFixtures.work()
            let policy=try MechanismSleepPolicy(maximumCoordinates:8,kineticEnergyThreshold:1e-5,normalizedVelocityThreshold:1e-5)
            let resting=try ConnectedMechanismSleep().evaluate(system,sample:sample,wakeCoordinateIDs:[],policy:policy,work:&work)
            #expect(resting.groups.count == 1);#expect(resting.groups[0] == [10,20]);#expect(resting.asleep == [true])
            let commanded=try ConnectedMechanismSleep().evaluate(system,sample:sample,wakeCoordinateIDs:[20],policy:policy,work:&work)
            #expect(commanded.asleep == [false]);#expect(commanded.kineticEnergy == [0])
            let moving=try MechanismFixtures.system(MechanismFixtures.model(v:[2,-1]))
            let energy=try ConnectedMechanismSleep().evaluate(moving,sample:sample,wakeCoordinateIDs:[],policy:policy,work:&work)
            #expect(energy.asleep == [false]);#expect(abs(energy.kineticEnergy[0]-6) < 1e-9)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func unknownWakeAndCancellationRejected() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let system=try MechanismFixtures.system(MechanismFixtures.model()),sample=try MechanismFixtures.sample()
            var work=try MechanismFixtures.work()
            let policy=try MechanismSleepPolicy(maximumCoordinates:8,kineticEnergyThreshold:0,normalizedVelocityThreshold:0),cancelled=try MechanismSleepPolicy(maximumCoordinates:8,kineticEnergyThreshold:0,normalizedVelocityThreshold:0,isCancelled:{true})
            do throws(MechanismError) { _=try ConnectedMechanismSleep().evaluate(system,sample:sample,wakeCoordinateIDs:[99],policy:policy,work:&work);Issue.record("Unknown wake coordinate accepted.") }
            catch { if case .invalidInput=error {} else { Issue.record("Expected invalid input.") } }
            do throws(MechanismError) { _=try ConnectedMechanismSleep().evaluate(system,sample:sample,wakeCoordinateIDs:[],policy:cancelled,work:&work);Issue.record("Cancelled sleep query accepted.") }
            catch { if case .cancelled=error {} else { Issue.record("Expected cancellation.") } }
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
