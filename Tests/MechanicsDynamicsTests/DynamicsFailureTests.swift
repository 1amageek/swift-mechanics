import Testing
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsLoads
import MechanicsDynamics
@Suite struct DynamicsFailureTests {
    @Test func velocityIdentityAndCallerAdmission() throws {
        var loadWork = try DynamicsFixtures.loadWork()
        let input = try DynamicsFixtures.pendulum(), kernel: any RigidEquationComputing = RigidEquationKernel()
        var work = try DynamicsFixtures.work()
        let mismatched = try RigidDynamicsInput(snapshot:input.snapshot,velocity:[8],inertias:input.inertias,gravity:input.gravity)
        #expect(throws:DynamicsError.velocityMismatch) { try kernel.assemble(mismatched,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work) }
        let wrong = try RigidBodyInertia(body:DynamicsFixtures.id(.body,"other"),frame:input.inertias[1].frame,properties:input.inertias[1].properties)
        let badIdentity = try RigidDynamicsInput(snapshot:input.snapshot,velocity:input.velocity,inertias:[input.inertias[0],wrong],gravity:input.gravity)
        #expect(throws:DynamicsError.inertiaIdentityMismatch) { try kernel.assemble(badIdentity,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work) }
        let missing = try RigidDynamicsInput(snapshot:input.snapshot,velocity:input.velocity,inertias:[input.inertias[0]],gravity:input.gravity)
        #expect(throws:DynamicsError.invalidShape) { try kernel.assemble(missing,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work) }
        #expect(throws:DynamicsError.capacityExceeded) { try kernel.assemble(input,admission:DynamicsFixtures.admission(bodies:1),loadWork:&loadWork,work:&work) }
        let badField = try AffineGravity(frame:DynamicsFixtures.id(.frame,"foreign"),accelerationAtOrigin:.zero)
        let wrongGravity = try RigidDynamicsInput(snapshot:input.snapshot,velocity:input.velocity,inertias:input.inertias,gravity:badField)
        #expect(throws:DynamicsError.frameMismatch) { try kernel.assemble(wrongGravity,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work) }
        let gradient = try AffineGravity(frame:DynamicsFixtures.id(.frame,"world"),accelerationAtOrigin:.zero,gradient:.identity)
        let nonuniform = try RigidDynamicsInput(snapshot:input.snapshot,velocity:input.velocity,inertias:input.inertias,gravity:gradient)
        #expect(throws:DynamicsError.unsupportedDomain) { try kernel.assemble(nonuniform,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work) }
        let base = try DynamicsFixtures.properties(mass:1)
        let fixedSnapshot = try DynamicsFixtures.snapshot(bodies:[DynamicsFixtures.body("fixed",properties:base)],joints:[],root:"fixed",q:[],v:[],acceleration:[])
        let fixed = try RigidDynamicsInput(snapshot:fixedSnapshot,velocity:[],inertias:[DynamicsFixtures.inertia("fixed",base)],gravity:nil)
        #expect(throws:DynamicsError.unsupportedDomain) { try kernel.assemble(fixed,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work) }
    }
    @Test func everyResourceBoundaryAndNumericalFailure() throws {
        var loadWork = try DynamicsFixtures.loadWork()
        let input = try DynamicsFixtures.pendulum(), kernel = RigidEquationKernel()
        var noStorage = try DynamicsFixtures.work(storage:12), noWork = try DynamicsFixtures.work(operations:0)
        #expect(throws:DynamicsError.numerical(.resourceLimit(resource:.scalarStorage,limit:12),failedSupplierWorkUnavailable:false)) { try kernel.assemble(input,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&noStorage) }
        #expect(throws:DynamicsError.numerical(.resourceLimit(resource:.arithmeticOperations,limit:0),failedSupplierWorkUnavailable:false)) { try kernel.assemble(input,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&noWork) }
        var exhaustedLoads = LoadWork(budget:try LoadBudget(maximumWork:1,maximumScalars:0))
        var loadNumerics = try DynamicsFixtures.work()
        #expect(throws:DynamicsError.loads(.workExhausted)) { try kernel.assemble(input,admission:DynamicsFixtures.admission(),loadWork:&exhaustedLoads,work:&loadNumerics) }
        #expect(exhaustedLoads.consumed == 1 && loadNumerics.operations > 0)
        var work = try DynamicsFixtures.work(), noIterations = try DynamicsFixtures.work(iterations:0)
        let system = try kernel.assemble(input,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work)
        let solver: any RigidDynamicsSolving = DenseRigidDynamics()
        var queryStorage = try DynamicsFixtures.work(storage:6)
        #expect(throws:DynamicsError.numerical(.resourceLimit(resource:.scalarStorage,limit:6),failedSupplierWorkUnavailable:false)) { try kernel.energy(system,acceleration:[0],angularMomentumReference:.zero,requireComplete:true,work:&queryStorage) }
        #expect(throws:DynamicsError.numerical(.resourceLimit(resource:.iterations,limit:0),failedSupplierWorkUnavailable:true)) { try solver.forward(system,driveForce:[10],policy:DynamicsFixtures.policy(1),work:&noIterations) }
        #expect(noIterations.operations > 0 && noIterations.iterations == 0)
        #expect(throws:DynamicsError.numerical(.nonPositiveDefinite(pivot:0),failedSupplierWorkUnavailable:true)) { try solver.forward(system,driveForce:[10],policy:DynamicsFixtures.policy(1,pivot:100),work:&work) }
        #expect(throws:DynamicsError.numerical(.unsupportedCapability,failedSupplierWorkUnavailable:false)) { try solver.forward(system,driveForce:[10],policy:DynamicsFixtures.policy(1,algorithm:.partialPivotLU),work:&work) }
        let valid = try solver.forward(system,driveForce:[10],policy:DynamicsFixtures.policy(1),work:&work)
        #expect(valid.work.peakScalarStorage >= 21 && valid.work.iterations == 1)
        var nestedStorage = try DynamicsFixtures.work(storage:20)
        #expect(throws:DynamicsError.numerical(.resourceLimit(resource:.scalarStorage,limit:8),failedSupplierWorkUnavailable:true)) { try solver.forward(system,driveForce:[10],policy:DynamicsFixtures.policy(1),work:&nestedStorage) }
        var shortWork = try DynamicsFixtures.work(operations:1)
        #expect(throws:DynamicsError.numerical(.resourceLimit(resource:.arithmeticOperations,limit:1),failedSupplierWorkUnavailable:false)) { try solver.forward(system,driveForce:[10],policy:DynamicsFixtures.policy(1),work:&shortWork) }
    }
    @Test func prematureNumericalSuccessRejectedByOriginalBodyEquation() throws {
        var loadWork = try DynamicsFixtures.loadWork()
        var work = try DynamicsFixtures.work()
        let system = try RigidEquationKernel().assemble(DynamicsFixtures.pendulum(),admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work)
        let solver = DenseRigidDynamics(linearSolver:ZeroReportingLinearSolver<Double>())
        let policy = try DynamicsFixtures.policy(1)
        do {
            _ = try solver.forward(system,driveForce:[10],policy:policy,work:&work)
            Issue.record("Incorrect numerical values must fail original physical residual acceptance")
        } catch {
            switch error {
            case .physicalResidualRejected(let value, let threshold): #expect(value > threshold)
            default: Issue.record("Unexpected failure: \(error)")
            }
        }
    }
    @Test func partitionBoundariesAndReusableOriginalBuffer() throws {
        var loadWork = try DynamicsFixtures.loadWork()
        var work = try DynamicsFixtures.work()
        let kernel = RigidEquationKernel(), system = try kernel.assemble(DynamicsFixtures.twoLink(),admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work)
        let solver: any RigidDynamicsSolving = DenseRigidDynamics()
        #expect(throws:DynamicsError.invalidShape) { try solver.mixed(system,partition:[.prescribedAcceleration(0)],policy:DynamicsFixtures.policy(2),work:&work) }
        #expect(throws:DynamicsError.invalidInput) { try solver.mixed(system,partition:[.prescribedAcceleration(.nan),.prescribedDriveForce(0)],policy:DynamicsFixtures.policy(2),work:&work) }
        var noIterations = try DynamicsFixtures.work(iterations:0)
        let allKnown = try solver.mixed(system,partition:[.prescribedAcceleration(0.4),.prescribedAcceleration(-0.6)],policy:DynamicsFixtures.policy(2),work:&noIterations)
        #expect(allKnown.acceleration == [0.4,-0.6] && allKnown.linearDiagnostics == nil && allKnown.originalPhysicalResidual.isAccepted)
        var output = [Double.nan,Double.nan]
        try kernel.originalInertialForce(system,acceleration:[0,0],includeBias:true,into:&output,work:&work)
        #expect(abs(output[0]-system.inertialBias[0]) < 1e-10 && abs(output[1]-system.inertialBias[1]) < 1e-10)
        try kernel.originalInertialForce(system,acceleration:[0,0],includeBias:false,into:&output,work:&work)
        #expect(output == [0,0])
        #expect(system.input.velocity == [0.8,-0.4])
    }
    @Test func callerCancellationBeforeAnyAcceptedResult() throws {
        var loadWork = try DynamicsFixtures.loadWork()
        var work = try DynamicsFixtures.work()
        #expect(throws:DynamicsError.cancelled) { try RigidEquationKernel().assemble(DynamicsFixtures.pendulum(),admission:DynamicsFixtures.admission(cancelled:true),loadWork:&loadWork,work:&work) }
        #expect(work.operations == 0)
    }
}
