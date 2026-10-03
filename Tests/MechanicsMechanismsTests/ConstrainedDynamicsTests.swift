import Testing
import MechanicsConstraints
import MechanicsMechanisms

@Suite struct ConstrainedDynamicsTests {
    @Test func realMassNonunitGearReaction() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let system=try MechanismFixtures.system(MechanismFixtures.model())
            #expect(system.massMatrix == [2,0,0,4])
            var work=try MechanismFixtures.work(),dynamics=try MechanismFixtures.work(),rank=try MechanismFixtures.work(),linear=try MechanismFixtures.work()
            let result=try MassWeightedMechanismSolver().acceleration(system,sample:MechanismFixtures.sample(),drive:[6,0],policy:MechanismFixtures.policy(),
                work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear)
            #expect(abs(result.values[0]-2) < 1e-9);#expect(abs(result.values[1]+1) < 1e-9)
            #expect(abs(result.rowMultipliers[0]+2) < 1e-9)
            #expect(abs(result.generalizedReaction[0]+2) < 1e-9);#expect(abs(result.generalizedReaction[1]+4) < 1e-9)
            #expect(result.rank.reactionsUnique);#expect(result.originalPhysicalResidual < 1e-9)
            #expect(dynamics.operations > 0 && rank.operations > 0 && linear.operations > 0)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func redundantRowsRetainedAndInconsistentOriginalRejected() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let system=try MechanismFixtures.system(MechanismFixtures.model()),solver=MassWeightedMechanismSolver()
            var work=try MechanismFixtures.work(),dynamics=try MechanismFixtures.work(),rank=try MechanismFixtures.work(),linear=try MechanismFixtures.work()
            let result=try solver.acceleration(system,sample:MechanismFixtures.sample(rows:[2,6,4,12],ids:[1,2],bias:[0,0]),drive:[6,0],policy:MechanismFixtures.policy(),
                work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear)
            #expect(result.rowIDs == [1,2]);#expect(result.rank.reactionNullity == 1);#expect(!result.rank.reactionsUnique)
            #expect(result.rowMultipliers[1] == 0)
            // A different retained-row multiplier vector [0,-1] gives the same physical torques.
            #expect(abs(result.generalizedReaction[0]-(-1*4.0/2)) < 1e-9)
            #expect(abs(result.generalizedReaction[1]-(-1*12.0/3)) < 1e-9)
            let inconsistent=try MechanismFixtures.sample(rows:[2,6,4,12],ids:[1,2],bias:[0,1]),policy=try MechanismFixtures.policy()
            do throws(MechanismError) {
                _=try solver.acceleration(system,sample:inconsistent,drive:[6,0],policy:policy,
                    work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear)
                Issue.record("Inconsistent dependent original row was accepted.")
            } catch { if case .originalConstraint(let row,_)=error { #expect(row == 2) } else { Issue.record("Unexpected typed error.") } }
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func movingShaftLockMomentumAndEnergy() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let system=try MechanismFixtures.system(MechanismFixtures.model(v:[3,-1]))
            var work=try MechanismFixtures.work(),dynamics=try MechanismFixtures.work(),rank=try MechanismFixtures.work(),linear=try MechanismFixtures.work()
            let result=try MassWeightedMechanismSolver().reconcileVelocity(system,sample:MechanismFixtures.sample(rows:[2,-3]),policy:MechanismFixtures.policy(),
                work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear)
            #expect(abs(result.values[0]-1.0/3) < 1e-9);#expect(abs(result.values[1]-1.0/3) < 1e-9)
            #expect(abs(2*result.values[0]+4*result.values[1]-2) < 1e-9)
            #expect(abs((result.kineticEnergyChange ?? .infinity)+32.0/3) < 1e-9)
            #expect(abs(result.generalizedReaction[0]+result.generalizedReaction[1]) < 1e-9)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
    @Test func cancellationAndCapacityFailBeforePublication() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let system=try MechanismFixtures.system(MechanismFixtures.model());var work=try MechanismFixtures.work(storage:0),d=try MechanismFixtures.work(),r=try MechanismFixtures.work(),l=try MechanismFixtures.work()
            let sample=try MechanismFixtures.sample(),cancelled=try MechanismFixtures.policy(cancelled:true),policy=try MechanismFixtures.policy()
            do throws(MechanismError) { _=try MassWeightedMechanismSolver().acceleration(system,sample:sample,drive:[6,0],policy:cancelled,work:&work,dynamicsWork:&d,rankWork:&r,linearWork:&l);Issue.record("Cancelled computation succeeded.") }
            catch { if case .cancelled=error {} else { Issue.record("Expected cancellation.") } }
            do throws(MechanismError) { _=try MassWeightedMechanismSolver().acceleration(system,sample:sample,drive:[6,0],policy:policy,work:&work,dynamicsWork:&d,rankWork:&r,linearWork:&l);Issue.record("Capacity-zero computation succeeded.") }
            catch { #expect(work.peakScalarStorage == 0) }
            #expect(d.operations == 0 && r.operations == 0 && l.operations == 0)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
