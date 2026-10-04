import SwiftMechanics
import Testing

@Suite struct PhysicalConstrainedMechanismTests {
    @Test(.timeLimit(.minutes(1))) func planarAccelerationRetainsCompleteSourceAndOriginalForceAndImpulseEnergy() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(v:[1,0],planar:true),system=try PhysicalMechanismFixtures.system(model)
            let solver:any PhysicalConstrainedMechanismSolving=PhysicalMechanismFixtures.solver(),sample=try MechanismFixtures.sample(),policy=try MechanismFixtures.policy()
            var a=try MechanismFixtures.work(),b=try MechanismFixtures.work(),c=try MechanismFixtures.work(),d=try MechanismFixtures.work()
            let result=try solver.acceleration(system,sample:sample,drive:[6,0],policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d)
            #expect(result.system === system);#expect(result.system.input.dimension == .planar)
            #expect(abs(result.motion.values[0]-2) < 1e-10);#expect(abs(result.motion.values[1]+1) < 1e-10)
            #expect(abs(result.motion.generalizedReaction[0]+2) < 1e-10);#expect(abs(result.motion.generalizedReaction[1]+4) < 1e-10)
            #expect(abs(2*result.motion.values[0]-6-result.motion.generalizedReaction[0]) < 1e-10)
            #expect(abs(4*result.motion.values[1]-result.motion.generalizedReaction[1]) < 1e-10)
            #expect(result.motion.sourceVelocity == [1,0]);#expect(result.motion.temporalMeaning == .accelerationForce)
            let impulse=try solver.reconcileVelocity(system,sample:sample,policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d)
            #expect(impulse.system === system);#expect(impulse.motion.temporalMeaning == .instantaneousVelocityImpulse)
            #expect(abs(impulse.motion.values[0]-2.0/3) < 1e-10);#expect(abs(impulse.motion.values[1]+1.0/3) < 1e-10)
            #expect(abs(try #require(impulse.motion.kineticEnergyChange)+1.0/3) < 1e-10)
            #expect(a.operations > 0);#expect(b.operations > 0);#expect(c.operations > 0);#expect(d.operations > 0)
        }
    }
    @Test(.timeLimit(.minutes(1))) func legacyOnlyCapabilityAndDifferentActualPhysicalSourceAreRejected() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let system=try PhysicalMechanismFixtures.system(MechanismFixtures.model(planar:true)),sample=try MechanismFixtures.sample(),policy=try MechanismFixtures.policy()
            var a=try MechanismFixtures.work(),b=try MechanismFixtures.work(),c=try MechanismFixtures.work(),d=try MechanismFixtures.work()
            do throws(MechanismError) { _=try MassWeightedMechanismSolver().acceleration(system,sample:sample,drive:[6,0],policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d);Issue.record("Legacy-only supplier admitted planar") }
            catch { if case .unsupportedChart=error {} else { Issue.record("Wrong capability failure") } }
            #expect(a.operations == 0);#expect(b.operations == 0)
            let other=try PhysicalMechanismFixtures.system(MechanismFixtures.model(q:[0.3,0],planar:true))
            let solver=MassWeightedMechanismSolver(physicalDynamics:WrongSourcePhysicalDynamics(other:other),physicalEquations:RigidEquationKernel())
            do throws(MechanismError) { _=try solver.acceleration(system,sample:sample,drive:[6,0],policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d);Issue.record("Different original source accepted") }
            catch { if case .dynamics(.inertiaIdentityMismatch)=error {} else { Issue.record("Wrong source failure") } }
            #expect(b.operations > 0);#expect(c.operations == 0)
        }
    }
    @Test(.timeLimit(.minutes(1))) func originalPhysicalCallbackResetSuccessFailureAndLegacyPhysicalInjectionPreserveAuthority() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let system=try PhysicalMechanismFixtures.system(MechanismFixtures.model(planar:true)),sample=try MechanismFixtures.sample(),policy=try MechanismFixtures.policy()
            for fault in [PhysicalMechanismFaultKernel.Fault.resetReturn,.resetThrow] {
                var a=try MechanismFixtures.work(),b=try MechanismFixtures.work(),c=try MechanismFixtures.work(),d=try MechanismFixtures.work()
                let solver=MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:PhysicalMechanismFaultKernel(fault:fault))
                do throws(MechanismError) { _=try solver.acceleration(system,sample:sample,drive:[6,0],policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d);Issue.record("Reset physical original force accepted") }
                catch { if case .supplierLedgerReplaced=error {} else { Issue.record("Wrong reset failure") };#expect(error.failedSupplierWorkUnavailable) }
                #expect(b.operations > 1);#expect(a.operations > 0)
            }
            let spatial=try MechanismFixtures.system(MechanismFixtures.model())
            let solver=MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:PhysicalMechanismFaultKernel(fault:.fail))
            var a=try MechanismFixtures.work(),b=try MechanismFixtures.work(),c=try MechanismFixtures.work(),d=try MechanismFixtures.work()
            do throws(MechanismError) { _=try solver.acceleration(spatial,sample:sample,drive:[6,0],policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d);Issue.record("Physical witness ignored by old spatial signature") }
            catch { if case .dynamics(.energyUnavailable)=error {} else { Issue.record("Wrong injected failure") };#expect(!error.failedSupplierWorkUnavailable) }
            #expect(b.operations > 0)
            let legacy=MassWeightedMechanismSolver(dynamics:ResettingDynamicsProvider()),tagged=PhysicalRigidDynamicsSystem(spatial:spatial)
            var e=try MechanismFixtures.work(),f=try MechanismFixtures.work(),g=try MechanismFixtures.work(),h=try MechanismFixtures.work()
            do throws(MechanismError) { _=try legacy.acceleration(tagged,sample:sample,drive:[6,0],policy:policy,work:&e,dynamicsWork:&f,rankWork:&g,linearWork:&h);Issue.record("Legacy witness ignored by tagged spatial signature") }
            catch { if case .supplierLedgerReplaced=error {} else { Issue.record("Wrong legacy injection failure") };#expect(error.failedSupplierWorkUnavailable) }
            #expect(f.operations == 1);#expect(g.operations == 0)
        }
    }
}
