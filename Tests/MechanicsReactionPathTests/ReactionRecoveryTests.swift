import Testing
import SwiftMechanics

@Suite struct ReactionRecoveryTests {
    private func policy(_ n: Int, bodies: Int = 10, cancelled: Bool = false) throws -> TreeReactionPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-9, relative: 1e-10)
        return try TreeReactionPolicy(maximumBodies: bodies, maximumJoints: 10, maximumBodyLoads: 20,
            generalizedForceScales: [Double](repeating: 1, count: n), generalizedTolerance: tolerance,
            forceTolerance: tolerance, torqueTolerance: tolerance, isCancelled: { cancelled })
    }
    private func close(_ a: Vector3, _ b: Vector3) throws -> Bool { try a.subtracting(b).magnitude() < 1e-8 }
    @Test func pendulumPhysicalSupportAndActionReaction() throws {
        let input = try ReactionFixtures.pendulum(theta: 0, speed: 1)
        var work = try ReactionFixtures.work(), loads = try ReactionFixtures.loadWork()
        let system = try RigidEquationKernel().assemble(input, admission: ReactionFixtures.admission(), loadWork: &loads, work: &work)
        let recovery: any TreeReactionRecovering = TreeReactionRecovery()
        let report = try recovery.recover(system, acceleration: [-10.0 / 3], topology: .completeTree,
            outputFrame: input.snapshot.tree.worldFrame, policy: policy(1), loadWork: &loads, work: &work)
        let joint = try #require(report.joints.first), support = try #require(report.support)
        // Child-only Newton/Euler: m=2, COM=(1,0,0), omega=1, alpha=-10/3, g=(0,-10,0).
        #expect(try close(joint.parentOnChild.force, Vector3(-2, 40.0 / 3, 0)))
        #expect(try close(joint.parentOnChild.torque, .zero))
        #expect(try close(joint.childOnParent.force, joint.parentOnChild.force.scaled(by: -1)))
        #expect(try close(joint.childOnParent.torque, joint.parentOnChild.torque.scaled(by: -1)))
        // The fixed root owns its own mass=1 weight; it is not part of the hinge child subtree.
        #expect(try close(support.supportOnRoot.force, Vector3(-2, 70.0 / 3, 0)))
        #expect(joint.referencePointWorld == .zero && joint.frame == input.snapshot.tree.worldFrame)
        #expect(joint.temporalMeaning == .instantaneousContinuousForce && report.fidelity == .spatialRigidTreeBalance)
        #expect(joint.timeSeconds == 0 && joint.revision == 7 && report.topologyAssumption == .completeTree)
        #expect(report.maximumScaledOriginalGeneralizedResidual < 1e-9)
        #expect(loads.consumed == system.assemblyLoadWork.consumed + 4)
    }
    @Test func childSubtreeOffsetBearingForceAndFrameConversion() throws {
        let root = try ReactionFixtures.properties(mass: 1)
        let first = try ReactionFixtures.properties(mass: 2, com: Vector3(0, -1, 0))
        let second = try ReactionFixtures.properties(mass: 3, com: Vector3(0, -1, 0))
        let firstJoint = try ReactionFixtures.hinge("first", parent: "root", child: "first")
        let secondJoint = try ReactionFixtures.hinge("second", parent: "first", child: "second",
            parentPlacement: .fixed(RigidTransform(rotation: .identity, translation: Vector3(0, -2, 0))))
        let snapshot = try ReactionFixtures.snapshot(bodies: [ReactionFixtures.body("root", properties: root),
            ReactionFixtures.body("first", properties: first), ReactionFixtures.body("second", properties: second)],
            joints: [firstJoint, secondJoint], root: "root", q: [0,0], v: [0,0], acceleration: [0,0])
        let applied = try BodyWrenchContribution(body: secondJoint.childBody, frame: snapshot.tree.worldFrame,
            referencePoint: Vector3(0,-4,0), wrench: SpatialWrench(torque: .zero, force: Vector3(0,0,4)), channel: .applied)
        let input = try RigidDynamicsInput(snapshot: snapshot, velocity: [0,0], inertias: [ReactionFixtures.inertia("root",root),
            ReactionFixtures.inertia("first",first),ReactionFixtures.inertia("second",second)],
            gravity: AffineGravity(frame: snapshot.tree.worldFrame, accelerationAtOrigin: Vector3(0,-10,0)), bodyWrenches: [applied])
        var work = try ReactionFixtures.work(), loads = try ReactionFixtures.loadWork()
        let system = try RigidEquationKernel().assemble(input, admission: ReactionFixtures.admission(), loadWork: &loads, work: &work)
        let report = try TreeReactionRecovery().recover(system, acceleration: [0,0], topology: .completeTree,
            outputFrame: snapshot.tree.worldFrame, policy: policy(2), loadWork: &loads, work: &work)
        #expect(try close(report.joints[0].parentOnChild.force, Vector3(0,50,-4)))
        #expect(try close(report.joints[0].parentOnChild.torque, Vector3(16,0,0)))
        #expect(try close(report.joints[1].parentOnChild.force, Vector3(0,30,-4)))
        #expect(try close(report.joints[1].parentOnChild.torque, Vector3(8,0,0)))
        #expect(try close(try #require(report.support).supportOnRoot.force, Vector3(0,60,-4)))
        let moved = try TreeReactionRecovery().recover(system, acceleration: [0,0], topology: .completeTree,
            outputFrame: secondJoint.childAnchor.frame, policy: policy(2), loadWork: &loads, work: &work)
        #expect(try close(moved.joints[0].referencePoint, Vector3(0,2,0)))
        #expect(try close(moved.joints[1].referencePoint, .zero))
        #expect(try close(moved.joints[1].childOnParent.torque, Vector3(-8,0,0)))
    }
    @Test func bodyFramedLoadRotationAndMomentReference() throws {
        let point = try Vector3(0,0,1)
        let load = try BodyWrenchContribution(body: ReactionFixtures.id(.body,"pendulum"), frame: ReactionFixtures.id(.frame,"pendulum-frame"),
            referencePoint: point, wrench: SpatialWrench(torque: .zero, force: Vector3(2,0,0)), channel: .applied)
        let input = try ReactionFixtures.pendulum(theta: .pi / 2, speed: 0, loads: [load])
        var work = try ReactionFixtures.work(), loads = try ReactionFixtures.loadWork()
        let system = try RigidEquationKernel().assemble(input, admission: ReactionFixtures.admission(), loadWork: &loads, work: &work)
        let report = try TreeReactionRecovery().recover(system, acceleration: [0], topology: .completeTree,
            outputFrame: input.snapshot.bodies[1].bodyFrame, policy: policy(1), loadWork: &loads, work: &work)
        // Body force maps to world +Y. Its off-plane point creates world torque -X, hence reaction +X.
        #expect(try close(report.joints[0].parentOnChild.force, Vector3(18,0,0)))
        #expect(try close(report.joints[0].parentOnChild.torque, Vector3(0,-2,0)))
        #expect(try close(report.joints[0].childOnParent.torque, Vector3(0,2,0)))
    }
    @Test func prescribedMotionUsesOriginalBodyBias() throws {
        let input = try ReactionFixtures.pendulum(theta:0,speed:0,prescribed:true)
        var work = try ReactionFixtures.work(), loads = try ReactionFixtures.loadWork()
        let system = try RigidEquationKernel().assemble(input,admission:ReactionFixtures.admission(),loadWork:&loads,work:&work)
        let report = try TreeReactionRecovery().recover(system,acceleration:[-10.0/3],topology:.completeTree,
            outputFrame:input.snapshot.tree.worldFrame,policy:policy(1),loadWork:&loads,work:&work)
        #expect(try close(report.joints[0].parentOnChild.force, Vector3(6,40.0/3,0)))
        #expect(try close(report.joints[0].parentOnChild.torque, .zero))
        #expect(try close(try #require(report.support).supportOnRoot.force, Vector3(6,70.0/3,0)))
    }
    @Test func floatingFreeBodyNoInventedSupport() throws {
        let properties = try ReactionFixtures.properties(mass: 2)
        let snapshot = try ReactionFixtures.snapshot(bodies: [ReactionFixtures.body("free",properties:properties)], joints: [], root: "free", base: .spatialFloating,
            q: [0,0,0,1,0,0,0], v: [0,0,0,0,0,0], acceleration: [0,0,0,0,0,0])
        let input = try RigidDynamicsInput(snapshot:snapshot,velocity:[0,0,0,0,0,0],inertias:[ReactionFixtures.inertia("free",properties)],
            gravity:AffineGravity(frame:snapshot.tree.worldFrame,accelerationAtOrigin:Vector3(0,-10,0)))
        var work = try ReactionFixtures.work(), loads = try ReactionFixtures.loadWork()
        let system = try RigidEquationKernel().assemble(input,admission:ReactionFixtures.admission(),loadWork:&loads,work:&work)
        let report = try TreeReactionRecovery().recover(system,acceleration:[0,-10,0,0,0,0],topology:.completeTree,
            outputFrame:snapshot.tree.worldFrame,policy:policy(6),loadWork:&loads,work:&work)
        #expect(report.support == nil && report.joints.isEmpty)
    }
    @Test func incompletePhysicalAllocationAndOriginalResidualFail() throws {
        let base = try ReactionFixtures.pendulum(theta:0,speed:0)
        let contribution = try GeneralizedForceContribution(values:[1],channel:.actuator)
        let input = try RigidDynamicsInput(snapshot:base.snapshot,velocity:base.velocity,inertias:base.inertias,gravity:base.gravity,generalizedForces:[contribution])
        var work = try ReactionFixtures.work(), loads = try ReactionFixtures.loadWork()
        let kernel = RigidEquationKernel()
        let system = try kernel.assemble(input,admission:ReactionFixtures.admission(),loadWork:&loads,work:&work)
        #expect(throws:ReactionPathError.nonuniqueGeneralizedAllocation) {
            try TreeReactionRecovery().recover(system,acceleration:[0],topology:.completeTree,outputFrame:base.snapshot.tree.worldFrame,policy:policy(1),loadWork:&loads,work:&work)
        }
        let physical = try kernel.assemble(base,admission:ReactionFixtures.admission(),loadWork:&loads,work:&work)
        #expect(throws:ReactionPathError.unrepresentedConnections) {
            try TreeReactionRecovery().recover(physical,acceleration:[0],topology:.unrepresentedConnections,outputFrame:base.snapshot.tree.worldFrame,policy:policy(1),loadWork:&loads,work:&work)
        }
        #expect(throws:ReactionPathError.originalGeneralizedResidual(index:0,scaledValue:20)) {
            try TreeReactionRecovery().recover(physical,acceleration:[0],topology:.completeTree,outputFrame:base.snapshot.tree.worldFrame,policy:policy(1),loadWork:&loads,work:&work)
        }
    }
    @Test(arguments: [0, 3], [false, true])
    func gravityLedgerResetPreservesAdmittedPrefix(prefix: Int, failAfterReset: Bool) throws {
        let input = try ReactionFixtures.pendulum(theta:0,speed:0)
        var work = try ReactionFixtures.work(), assemblyLoads = try ReactionFixtures.loadWork()
        let system = try RigidEquationKernel().assemble(input,admission:ReactionFixtures.admission(),loadWork:&assemblyLoads,work:&work)
        // Start recovery from its own caller ledger; assembly work is not its admission evidence.
        var loads = try ReactionFixtures.loadWork()
        try loads.charge(prefix)
        #expect(throws:ReactionPathError.supplierLedgerReplaced) {
            try TreeReactionRecovery(gravity:ReactionErasingGravity(failAfterReset:failAfterReset)).recover(system,
                acceleration:[-10.0/3],topology:.completeTree,outputFrame:input.snapshot.tree.worldFrame,
                policy:policy(1),loadWork:&loads,work:&work)
        }
        #expect(loads.consumed == prefix + 1)
        #expect(loads.budget.maximumWork == 1000 && loads.budget.maximumScalars == 0)
    }
    @Test func gravityLedgerFailurePreservesOriginalCancellation() throws {
        let input = try ReactionFixtures.pendulum(theta:0,speed:0)
        var work = try ReactionFixtures.work(), assemblyLoads = try ReactionFixtures.loadWork()
        let system = try RigidEquationKernel().assemble(input,admission:ReactionFixtures.admission(),loadWork:&assemblyLoads,work:&work)
        var loads = try ReactionFixtures.loadWork()
        #expect(throws:ReactionPathError.supplierLedgerReplaced) {
            try TreeReactionRecovery(gravity:ReactionErasingGravity(failAfterReset:true,replaceCancellation:true)).recover(system,
                acceleration:[-10.0/3],topology:.completeTree,outputFrame:input.snapshot.tree.worldFrame,
                policy:policy(1),loadWork:&loads,work:&work)
        }
        #expect(loads.consumed == 1 && !loads.budget.isCancelled())
        try loads.charge(1)
        #expect(loads.consumed == 2)
    }
    @Test func capacitiesInvalidInputCancellationAndSupplierWorkFailures() throws {
        let input = try ReactionFixtures.pendulum(theta:0,speed:0)
        var work = try ReactionFixtures.work(), loads = try ReactionFixtures.loadWork()
        let system = try RigidEquationKernel().assemble(input,admission:ReactionFixtures.admission(),loadWork:&loads,work:&work)
        let recovery = TreeReactionRecovery(), frame = input.snapshot.tree.worldFrame
        #expect(throws:ReactionPathError.capacityExceeded) { try recovery.recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,policy:policy(1,bodies:1),loadWork:&loads,work:&work) }
        #expect(throws:ReactionPathError.cancelled) { try recovery.recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,policy:policy(1,cancelled:true),loadWork:&loads,work:&work) }
        #expect(throws:ReactionPathError.invalidInput) { try recovery.recover(system,acceleration:[.nan],topology:.completeTree,outputFrame:frame,policy:policy(1),loadWork:&loads,work:&work) }
        #expect(throws:ReactionPathError.invalidShape) { try recovery.recover(system,acceleration:[],topology:.completeTree,outputFrame:frame,policy:policy(1),loadWork:&loads,work:&work) }
        var exhausted = LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0))
        #expect(throws:ReactionPathError.loads(.workExhausted)) { try recovery.recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,policy:policy(1),loadWork:&exhausted,work:&work) }
        var erased = try ReactionFixtures.work()
        #expect(throws:ReactionPathError.supplierLedgerReplaced) { try TreeReactionRecovery(equations:ReactionErasingEquations()).recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,policy:policy(1),loadWork:&loads,work:&erased) }
        #expect(erased.operations > 0 && erased.peakScalarStorage > 0)
        #expect(ReactionPathError.supplierLedgerReplaced.failedSupplierWorkUnavailable)
        #expect(throws:ReactionPathError.supplierLedgerReplaced) { try TreeReactionRecovery(equations:ReactionErasingEquations(failAfterReset:true)).recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,policy:policy(1),loadWork:&loads,work:&erased) }
        let retainedLoadWork = loads.consumed
        #expect(throws:ReactionPathError.supplierLedgerReplaced) { try TreeReactionRecovery(gravity:ReactionErasingGravity()).recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,policy:policy(1),loadWork:&loads,work:&work) }
        #expect(loads.consumed == retainedLoadWork + 1)
        var noStorage = try ReactionFixtures.work(storage:0)
        #expect(throws:ReactionPathError.numerical(.resourceLimit(resource:.scalarStorage,limit:0))) { try recovery.recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,policy:policy(1),loadWork:&loads,work:&noStorage) }
        var noArithmetic = try ReactionFixtures.work(operations:0)
        #expect(throws:ReactionPathError.numerical(.resourceLimit(resource:.arithmeticOperations,limit:0))) { try recovery.recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,policy:policy(1),loadWork:&loads,work:&noArithmetic) }
    }
}
