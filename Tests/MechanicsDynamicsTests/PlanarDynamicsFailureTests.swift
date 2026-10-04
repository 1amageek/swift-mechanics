import SwiftMechanics
import Testing

@Suite struct PlanarDynamicsFailureTests {
    @Test(.timeLimit(.minutes(1))) func originalInventoryDimensionFrameAndVelocityRefusals() throws {
        let original=try PlanarDynamicsFixtures.free(),kernel:any PhysicalRigidEquationComputing=RigidEquationKernel()
        let snapshot=original.snapshot,inertias=original.inertias
        var load=try DynamicsFixtures.loadWork(),work=try DynamicsFixtures.work()
        let missing=try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:original.velocity,inertias:[],gravity:nil)
        #expect(throws:DynamicsError.invalidShape) { try kernel.assemble(PhysicalRigidDynamicsInput(planar:missing),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work) }
        let wrong=try PlanarRigidBodyInertia(body:DynamicsFixtures.id(.body,"foreign"),frame:inertias[0].frame,properties:inertias[0].properties)
        let wrongBody=try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:original.velocity,inertias:[wrong],gravity:nil)
        #expect(throws:DynamicsError.inertiaIdentityMismatch) { try kernel.assemble(PhysicalRigidDynamicsInput(planar:wrongBody),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work) }
        let wrongFrame=try PlanarRigidBodyInertia(body:inertias[0].body,frame:DynamicsFixtures.id(.frame,"foreign"),properties:inertias[0].properties)
        let frameInput=try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:original.velocity,inertias:[wrongFrame],gravity:nil)
        #expect(throws:DynamicsError.inertiaIdentityMismatch) { try kernel.assemble(PhysicalRigidDynamicsInput(planar:frameInput),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work) }
        let changed=try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:[2,3,4],inertias:inertias,gravity:nil)
        #expect(throws:DynamicsError.velocityMismatch) { try kernel.assemble(PhysicalRigidDynamicsInput(planar:changed),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work) }
        let spatial=try DynamicsFixtures.pendulum()
        let mismatch=try PlanarRigidDynamicsInput(snapshot:spatial.snapshot,velocity:spatial.velocity,inertias:inertias,gravity:nil)
        #expect(throws:DynamicsError.dimensionMismatch) { try kernel.assemble(PhysicalRigidDynamicsInput(planar:mismatch),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work) }
        let wrongGravity=try AffineGravity(frame:DynamicsFixtures.id(.frame,"foreign"),accelerationAtOrigin:.zero)
        let fieldInput=try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:original.velocity,inertias:inertias,gravity:wrongGravity)
        #expect(throws:DynamicsError.frameMismatch) { try kernel.assemble(PhysicalRigidDynamicsInput(planar:fieldInput),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work) }
    }
    @Test(.timeLimit(.minutes(1))) func planeLoadsRefusedInOriginalReferenceMeaning() throws {
        let kernel:any PhysicalRigidEquationComputing=RigidEquationKernel()
        var work=try DynamicsFixtures.work(),load=try DynamicsFixtures.loadWork()
        let body=try DynamicsFixtures.id(.body,"free-plane"),world=try DynamicsFixtures.id(.frame,"world"),bodyFrame=try DynamicsFixtures.id(.frame,"free-plane-frame")
        let loads=[
            try BodyWrenchContribution(body:body,frame:world,referencePoint:Vector3(1,-2,0),wrench:SpatialWrench(torque:.zero,force:.unitZ),channel:.applied),
            try BodyWrenchContribution(body:body,frame:bodyFrame,referencePoint:.zero,wrench:SpatialWrench(torque:.unitX,force:.zero),channel:.applied),
            try BodyWrenchContribution(body:body,frame:world,referencePoint:Vector3(1,-2,2),wrench:SpatialWrench(torque:.zero,force:.unitX),channel:.applied)
        ]
        for item in loads {
            let input=try PlanarDynamicsFixtures.free(loads:[item])
            #expect(throws:DynamicsError.nonplanarInput) { try kernel.assemble(PhysicalRigidDynamicsInput(planar:input),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work) }
        }
        let gravity=try AffineGravity(frame:world,accelerationAtOrigin:.unitZ)
        let input=try PlanarDynamicsFixtures.free(gravity:gravity)
        #expect(throws:DynamicsError.nonplanarInput) { try kernel.assemble(PhysicalRigidDynamicsInput(planar:input),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work) }
        let derivative=try AffineGravity(frame:world,accelerationAtOrigin:.zero,uniformTimeDerivative:.unitZ)
        let changing=try PlanarDynamicsFixtures.free(gravity:derivative)
        #expect(throws:DynamicsError.nonplanarInput) { try kernel.assemble(PhysicalRigidDynamicsInput(planar:changing),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work) }
        let nonuniform=try PlanarDynamicsFixtures.free(gravity:AffineGravity(frame:world,accelerationAtOrigin:.zero,gradient:.identity))
        #expect(throws:DynamicsError.unsupportedDomain) { try kernel.assemble(PhysicalRigidDynamicsInput(planar:nonuniform),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work) }
    }
    @Test(.timeLimit(.minutes(1))) func boundedQueriesPivotCapabilitiesAndWrongNumericalSuccess() throws {
        var work=try DynamicsFixtures.work();let system=try PlanarDynamicsFixtures.assemble(PlanarDynamicsFixtures.pendulum(),work:&work)
        let solver=PlanarDynamicsFixtures.solver(),policy=try DynamicsFixtures.policy(1)
        var noStorage=try DynamicsFixtures.work(storage:1),noOperations=try DynamicsFixtures.work(operations:0),noIterations=try DynamicsFixtures.work(iterations:0)
        #expect(throws:DynamicsError.numerical(.resourceLimit(resource:.scalarStorage,limit:1),failedSupplierWorkUnavailable:false)) { try solver.forward(system,driveForce:[1],policy:policy,work:&noStorage) }
        #expect(throws:DynamicsError.numerical(.resourceLimit(resource:.arithmeticOperations,limit:0),failedSupplierWorkUnavailable:false)) { try solver.forward(system,driveForce:[1],policy:policy,work:&noOperations) }
        #expect(throws:DynamicsError.numerical(.resourceLimit(resource:.iterations,limit:0),failedSupplierWorkUnavailable:true)) { try solver.forward(system,driveForce:[1],policy:policy,work:&noIterations) }
        #expect(noIterations.operations > 0 && noIterations.iterations == 0)
        let pivot=try DynamicsFixtures.policy(1,pivot:100),unsupported=try DynamicsFixtures.policy(1,algorithm:.partialPivotLU)
        #expect(throws:DynamicsError.numerical(.nonPositiveDefinite(pivot:0),failedSupplierWorkUnavailable:true)) { try solver.forward(system,driveForce:[1],policy:pivot,work:&work) }
        #expect(throws:DynamicsError.numerical(.unsupportedCapability,failedSupplierWorkUnavailable:false)) { try solver.forward(system,driveForce:[1],policy:unsupported,work:&work) }
        let wrong:any PhysicalRigidDynamicsSolving=DenseRigidDynamics(physicalEquations:RigidEquationKernel(),linearSolver:ZeroReportingLinearSolver<Double>())
        do throws(DynamicsError) { _=try wrong.forward(system,driveForce:[30],policy:policy,work:&work);Issue.record("False numerical success accepted") }
        catch {
            switch error {
            case .physicalResidualRejected(let value,let threshold): #expect(value > threshold)
            default: Issue.record("Unexpected error: \(error)")
            }
        }
        #expect(system.input.snapshot.time == 0 && system.input.velocity == [0.7])
    }
    @Test(.timeLimit(.minutes(1))) func callbackKnownPrefixResetAndLateCancellation() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            var assemblyWork=try DynamicsFixtures.work();let system=try PlanarDynamicsFixtures.assemble(PlanarDynamicsFixtures.pendulum(),work:&assemblyWork)
            let policy=try DynamicsFixtures.policy(1)
            var resetPrefix:Int?
            for mode in [PhysicalEquationFault.Mode.resetReturn,.resetThrow,.failAfterPrefix] {
                let supplier=PhysicalEquationFault(mode),solver:any PhysicalRigidDynamicsSolving=DenseRigidDynamics(physicalEquations:supplier)
                var work=try DynamicsFixtures.work()
                do throws(DynamicsError) { _=try solver.forward(system,driveForce:[1],policy:policy,work:&work);Issue.record("Failed physical supplier published success") }
                catch {
                    if mode == .failAfterPrefix { #expect(error == .cancelled && !error.failedSupplierWorkUnavailable) }
                    else { #expect(error == .supplierLedgerReplaced && error.failedSupplierWorkUnavailable) }
                }
                #expect(supplier.count() == 1 && work.operations > 2 && work.iterations == 1)
                if mode == .resetReturn { resetPrefix=work.operations }
                if mode == .resetThrow { #expect(resetPrefix == work.operations) }
                if mode == .failAfterPrefix,let resetPrefix { #expect(work.operations > resetPrefix) }
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func explicitWitnessSelectionRetainsAuthorityBothDirections() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            var load=try DynamicsFixtures.loadWork(),work=try DynamicsFixtures.work()
            let spatial=try RigidEquationKernel().assemble(DynamicsFixtures.pendulum(),admission:DynamicsFixtures.admission(),loadWork:&load,work:&work)
            let tagged=PhysicalRigidDynamicsSystem(spatial:spatial),legacy=SpatialEquationCounter(),policy=try DynamicsFixtures.policy(1)
            let oldSolver=DenseRigidDynamics(equations:legacy)
            _=try oldSolver.forward(spatial,driveForce:[1],policy:policy,work:&work)
            _=try oldSolver.forward(tagged,driveForce:[1],policy:policy,work:&work)
            #expect(legacy.count() == 2)
            let physical=PhysicalEquationFault(.observe),newSolver=DenseRigidDynamics(physicalEquations:physical)
            _=try newSolver.forward(spatial,driveForce:[1],policy:policy,work:&work)
            _=try newSolver.forward(tagged,driveForce:[1],policy:policy,work:&work)
            #expect(physical.count() == 2)
            let planar=try PlanarDynamicsFixtures.assemble(PlanarDynamicsFixtures.pendulum(),work:&work)
            var refused=try DynamicsFixtures.work()
            #expect(throws:DynamicsError.unsupportedDomain) { try oldSolver.forward(planar,driveForce:[1],policy:policy,work:&refused) }
            #expect(legacy.count() == 2 && refused.operations == 0)
        }
    }
    @Test(.timeLimit(.minutes(1))) func assemblyAdmissionCancelAndUnavailableEnergy() throws {
        let input=try PlanarDynamicsFixtures.free(),physical=PhysicalRigidDynamicsInput(planar:input),kernel:any PhysicalRigidEquationComputing=RigidEquationKernel()
        var load=try DynamicsFixtures.loadWork(),work=try DynamicsFixtures.work()
        #expect(throws:DynamicsError.cancelled) { try kernel.assemble(physical,admission:DynamicsFixtures.admission(cancelled:true),loadWork:&load,work:&work) }
        #expect(work.operations == 0 && load.consumed == 0)
        let small=DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:1,maximumVelocities:2,maximumBodyWrenches:0,maximumGeneralizedContributions:0),
            angularVelocityTolerance:try NumericalTolerance(absolute:1e-11,relative:1e-11),linearVelocityTolerance:try NumericalTolerance(absolute:1e-11,relative:1e-11))
        #expect(throws:DynamicsError.capacityExceeded) { try kernel.assemble(physical,admission:small,loadWork:&load,work:&work) }
        var noStorage=try DynamicsFixtures.work(storage:0)
        #expect(throws:DynamicsError.numerical(.resourceLimit(resource:.scalarStorage,limit:0),failedSupplierWorkUnavailable:false)) { try kernel.assemble(physical,admission:DynamicsFixtures.admission(),loadWork:&load,work:&noStorage) }
        let bodyLoad=try BodyWrenchContribution(body:input.inertias[0].body,frame:input.snapshot.tree.worldFrame,referencePoint:Vector3(1,-2,0),wrench:SpatialWrench(torque:.zero,force:.unitX),channel:.applied)
        let system=try PlanarDynamicsFixtures.assemble(PlanarDynamicsFixtures.free(loads:[bodyLoad]),work:&work)
        #expect(throws:DynamicsError.energyUnavailable) { try kernel.energy(system,acceleration:[0,0,0],angularMomentumReference:.zero,requireComplete:true,work:&work) }
        let unavailable=try kernel.energy(system,acceleration:[0,0,0],angularMomentumReference:.zero,requireComplete:false,work:&work)
        #expect(unavailable.potentialEnergy == nil && unavailable.dissipatedPower == nil)
    }
}
