@testable import SwiftMechanics
import Testing

@Suite struct InvalidGraphTests {
    @Test func duplicateDanglingCycleDisconnectedAndMultipleParent() throws {
        let root = try JointFixtures.body("root"), first = try JointFixtures.body("first"), second = try JointFixtures.body("second")
        #expect(throws: JointError.duplicateIdentity(root.id)) { try JointFixtures.tree(bodies: [root, root], joints: []) }
        let dangling = try JointFixtures.joint("dangling", parent: "absent", child: "first", specification: .fixed)
        #expect(throws: JointError.danglingBody(try JointFixtures.id(.body, "absent"))) { try JointFixtures.tree(bodies: [root, first], joints: [dangling]) }
        let firstJoint = try JointFixtures.joint("one", parent: "root", child: "first", specification: .fixed)
        let back = try JointFixtures.joint("back", parent: "first", child: "root", specification: .fixed)
        #expect(throws: JointError.cycle) { try JointFixtures.tree(bodies: [root, first], joints: [firstJoint, back]) }
        #expect(throws: JointError.disconnectedTree) { try JointFixtures.tree(bodies: [root, first, second], joints: [firstJoint]) }
        let duplicateParent = try JointFixtures.joint("two", parent: "second", child: "first", specification: .fixed)
        #expect(throws: JointError.multipleParents(first.id)) { try JointFixtures.tree(bodies: [root, first, second], joints: [firstJoint, duplicateParent]) }
        #expect(throws: JointError.duplicateIdentity(firstJoint.id)) { try JointFixtures.tree(bodies: [root, first], joints: [firstJoint, firstJoint]) }
        #expect(throws: JointError.invalidRoot) { try JointFixtures.tree(bodies: [root], joints: [], root: "unknown") }
        let planar = try JointFixtures.body("planar", planar: true)
        #expect(throws: JointError.mixedDimensions) { try JointFixtures.tree(bodies: [root, planar], joints: []) }
    }

    @Test func stateIdentityCapacityAndOverflowFailures() throws {
        let root = try JointFixtures.body("root"), tree = try JointFixtures.tree(bodies: [root], joints: [])
        let evaluator = TreeKinematicsEvaluator(), policy = try JointFixtures.policy()
        #expect(throws: JointError.stateRevisionMismatch) { try evaluator.evaluate(tree, state: KinematicState(revision: 4, time: 0, q: [], v: [], acceleration: []), policy: policy) }
        #expect(throws: JointError.invalidCoordinateCount) { try evaluator.evaluate(tree, state: JointFixtures.state(q: [0], v: []), policy: policy) }
        #expect(throws: JointError.nonFiniteState) { try JointFixtures.state(q: [.nan], v: []) }
        #expect(throws: JointError.integerOverflow) { try CoordinateRange(start: Int.max, count: 1) }
        let capacity = try KinematicCapacity(maximumBodies: Int.max, maximumVelocities: Int.max, maximumJacobianScalars: Int.max)
        #expect(throws: JointError.integerOverflow) { try capacity.validating(bodyCount: Int.max, velocityCount: 2) }
        #expect(throws: JointError.integerOverflow) { try capacity.validating(bodyCount: 1, velocityCount: Int.max) }
        let noBodies = try KinematicCapacity(maximumBodies: 0, maximumVelocities: 0, maximumJacobianScalars: 0)
        #expect(throws: JointError.capacityExceeded) { try KinematicTree(bodies: [root], joints: [], root: root.id, rootBase: .fixed,
            worldFrame: JointFixtures.id(.frame, "world"), revision: 5, capacity: noBodies) }
        let snapshot = try evaluator.evaluate(tree, state: JointFixtures.state(q: [], v: []), policy: policy)
        let unknown = try JointFixtures.id(.body, "unknown")
        #expect(throws: JointError.unknownBody(unknown)) { try KinematicJacobianCalculator().geometric(body: unknown, snapshot: snapshot) }
        let limited = try KinematicCapacity(maximumBodies: 2, maximumVelocities: 6, maximumJacobianScalars: 5)
        #expect(throws: JointError.capacityExceeded) { try KinematicTree(bodies: [root], joints: [], root: root.id, rootBase: .spatialFloating,
            worldFrame: JointFixtures.id(.frame, "world"), revision: 5, capacity: limited) }
    }

    @Test func prescribedSampleIdentityAndJacobianInputFailures() throws {
        let root = try JointFixtures.body("root"), child = try JointFixtures.body("child")
        let joint = try JointFixtures.joint("moving", parent: "root", child: "child", specification: .revolute(axis: .unitZ), parentPlacement: .prescribed)
        let tree = try JointFixtures.tree(bodies: [root, child], joints: [joint]), evaluator = TreeKinematicsEvaluator(), policy = try JointFixtures.policy()
        let sample = try PrescribedAnchorState(frame: joint.parentAnchor.frame, time: 0, motion: .stationary(pose: .identity))
        #expect(throws: JointError.duplicateIdentity(sample.frame)) { try evaluator.evaluate(tree, state: JointFixtures.state(q: [0], v: [0], anchors: [sample, sample]), policy: policy) }
        let unknown = try PrescribedAnchorState(frame: JointFixtures.id(.frame, "unknown"), time: 0, motion: .stationary(pose: .identity))
        #expect(throws: JointError.unknownDerivativeData(unknown.frame)) { try evaluator.evaluate(tree, state: JointFixtures.state(q: [0], v: [0], anchors: [unknown]), policy: policy) }
        let snapshot = try evaluator.evaluate(tree, state: JointFixtures.state(q: [0], v: [0], anchors: [sample]), policy: policy)
        let calculator = KinematicJacobianCalculator(), jacobian = try calculator.geometric(body: child.id, snapshot: snapshot)
        #expect(throws: JointError.invalidCoordinateCount) { try jacobian.applying([][...]) }
        #expect(throws: JointError.nonFiniteState) { try jacobian.applying([.infinity][...]) }
        let point = try calculator.point(body: child.id, bodyLocalPoint: .zero, snapshot: snapshot)
        #expect(throws: JointError.invalidCoordinateCount) { try point.applying([][...]) }
        #expect(throws: JointError.nonFiniteState) { try point.applying([.nan][...]) }
    }
}
