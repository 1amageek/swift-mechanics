import Testing
import MechanicsCore
import MechanicsModel
@testable import MechanicsJoints

@Suite struct TreeTests {
    @Test func planarSerialTransformsAndStableOrdering() throws {
        let root = try JointFixtures.body("root", planar: true), first = try JointFixtures.body("first", planar: true), second = try JointFixtures.body("second", planar: true)
        let firstAnchor = RigidTransform(rotation: .identity, translation: try Vector3(-2, 0, 0))
        let secondAnchor = RigidTransform(rotation: .identity, translation: try Vector3(-3, 0, 0))
        let hinge1 = try JointFixtures.joint("hinge1", parent: "root", child: "first", specification: .revolute(axis: .unitZ), childPlacement: .fixed(firstAnchor))
        let hinge2 = try JointFixtures.joint("hinge2", parent: "first", child: "second", specification: .revolute(axis: .unitZ), childPlacement: .fixed(secondAnchor))
        let tree = try JointFixtures.tree(bodies: [second, root, first], joints: [hinge2, hinge1])
        #expect(tree.layout.bodyOrder == [root.id, first.id, second.id])
        #expect(tree.layout.joints.map { $0.joint } == [hinge1.id, hinge2.id])
        let q = [Double.pi / 2, -Double.pi / 2], state = try JointFixtures.state(q: q, v: [0, 0])
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: state, policy: JointFixtures.policy())
        #expect(try snapshot.body(first.id).motion.pose.translation.subtracting(Vector3(0, 2, 0)).magnitude() < 1e-12)
        #expect(try snapshot.body(second.id).motion.pose.translation.subtracting(Vector3(3, 2, 0)).magnitude() < 1e-12)
        #expect(state.q == q && state.v == [0, 0])
        #expect(try snapshot.frame(second.frame).motion == snapshot.body(second.id).motion)
        #expect(try snapshot.frame(hinge2.childAnchor.frame).motion.pose.translation.subtracting(Vector3(0, 2, 0)).magnitude() < 1e-12)
        #expect(snapshot.joints.count == 2 && snapshot.frames.count == tree.frameCount)
        #expect(snapshot.joints[1].relative.coordinateRate == [0])
    }

    @Test func analyticRotatingSliderAccelerationAndBias() throws {
        let root = try JointFixtures.body("root"), rotor = try JointFixtures.body("rotor"), slider = try JointFixtures.body("slider")
        let hinge = try JointFixtures.joint("hinge", parent: "root", child: "rotor", specification: .revolute(axis: .unitZ))
        let slide = try JointFixtures.joint("slide", parent: "rotor", child: "slider", specification: .prismatic(axis: .unitX))
        let tree = try JointFixtures.tree(bodies: [root, rotor, slider], joints: [hinge, slide])
        let theta = Double.pi / 2, distance = 2.0, omega = 3.0, speed = 4.0, alpha = 5.0, linearAcceleration = 6.0
        let state = try JointFixtures.state(q: [theta, distance], v: [omega, speed], acceleration: [alpha, linearAcceleration])
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: state, policy: JointFixtures.policy())
        let body = try snapshot.body(slider.id)
        #expect(try body.motion.pose.translation.subtracting(Vector3(0, 2, 0)).magnitude() < 1e-12)
        #expect(try body.motion.velocity.linear.subtracting(Vector3(-6, 4, 0)).magnitude() < 1e-12)
        #expect(try body.motion.acceleration.linear.subtracting(Vector3(-(alpha * distance + 2 * omega * speed), linearAcceleration - omega * omega * distance, 0)).magnitude() < 1e-12)
        #expect(try body.motion.acceleration.angular.subtracting(Vector3(0, 0, alpha)).magnitude() < 1e-12)
        #expect(try body.accelerationBias.linear.subtracting(Vector3(-24, -18, 0)).magnitude() < 1e-12)
        #expect(try body.prescribedDriftVelocity.linear.magnitude() < 1e-12)
    }

    @Test func spatialAnchorsAndFloatingSevenSixRoundTrip() throws {
        let root = try JointFixtures.body("root"), child = try JointFixtures.body("child")
        let parentPose = RigidTransform(rotation: try UnitQuaternion(axis: .unitY, angle: Double.pi / 2), translation: try Vector3(1, 0, 0))
        let childPose = RigidTransform(rotation: try UnitQuaternion(axis: .unitX, angle: Double.pi / 2), translation: try Vector3(0, 2, 0))
        let joint = try JointFixtures.joint("fixed", parent: "root", child: "child", specification: .fixed,
                                           parentPlacement: .fixed(parentPose), childPlacement: .fixed(childPose))
        let tree = try JointFixtures.tree(bodies: [root, child], joints: [joint], base: .spatialFloating)
        #expect(tree.layout.positionCount == 7 && tree.layout.velocityCount == 6)
        let rotation = try UnitQuaternion(axis: .unitZ, angle: Double.pi / 2)
        let base = BaseState.spatial(pose: RigidTransform(rotation: rotation, translation: try Vector3(3, 4, 5)),
                                     worldLinearVelocity: try Vector3(1, 2, 3), bodyAngularVelocity: try Vector3(4, 5, 6))
        let coordinates = try BaseLayout.spatialFloating.encode(base)
        let state = try JointFixtures.state(q: coordinates.q, v: coordinates.v)
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: state, policy: JointFixtures.policy())
        let rootState = try snapshot.body(root.id)
        #expect(try rootState.motion.pose.translation.subtracting(Vector3(3, 4, 5)).magnitude() < 1e-12)
        #expect(try rootState.motion.velocity.angular.subtracting(Vector3(-5, 4, 6)).magnitude() < 1e-12)
        let recoveredBase = BaseState.spatial(pose: rootState.motion.pose, worldLinearVelocity: rootState.motion.velocity.linear,
            bodyAngularVelocity: try rootState.motion.pose.rotation.conjugated().rotating(rootState.motion.velocity.angular))
        let recovered = try BaseLayout.spatialFloating.encode(recoveredBase)
        for index in coordinates.q.indices { #expect(abs(recovered.q[index] - coordinates.q[index]) < 1e-12) }
        for index in coordinates.v.indices { #expect(abs(recovered.v[index] - coordinates.v[index]) < 1e-12) }
        let childState = try snapshot.body(child.id)
        let expected = try rootState.motion.pose.composed(with: parentPose).composed(with: childPose.inverted())
        #expect(try childState.motion.pose.transforming(point: .unitX).subtracting(expected.transforming(point: .unitX)).magnitude() < 1e-12)
        #expect(snapshot.coordinateRate.count == 7)
    }

    @Test func suppliedMovingAnchorTransportAndMissingDerivativeFailure() throws {
        let root = try JointFixtures.body("root"), child = try JointFixtures.body("child")
        let childAnchor = RigidTransform(rotation: .identity, translation: try Vector3(-2, 0, 0))
        let joint = try JointFixtures.joint("moving", parent: "root", child: "child", specification: .fixed,
                                           parentPlacement: .prescribed, childPlacement: .fixed(childAnchor))
        let tree = try JointFixtures.tree(bodies: [root, child], joints: [joint])
        let omega = 3.0, time = 0.0
        let sample = try PrescribedAnchorState(frame: joint.parentAnchor.frame, time: time,
            motion: FrameMotion(pose: .identity, velocity: SpatialMotion(angular: Vector3(0, 0, omega), linear: Vector3(4, 0, 0)),
                                acceleration: SpatialMotion(angular: Vector3(0, 0, 5), linear: Vector3(6, 0, 0))))
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: JointFixtures.state(q: [], v: [], time: time, anchors: [sample]), policy: JointFixtures.policy())
        let body = try snapshot.body(child.id)
        #expect(try body.motion.velocity.linear.subtracting(Vector3(4, 6, 0)).magnitude() < 1e-12)
        #expect(try body.motion.acceleration.linear.subtracting(Vector3(-12, 10, 0)).magnitude() < 1e-12)
        #expect(body.prescribedDriftVelocity == body.motion.velocity)
        #expect(body.accelerationBias == body.motion.acceleration)
        #expect(throws: JointError.missingDerivativeData(joint.parentAnchor.frame)) {
            try TreeKinematicsEvaluator().evaluate(tree, state: JointFixtures.state(q: [], v: []), policy: JointFixtures.policy())
        }
        #expect(throws: JointError.staleDerivativeData(joint.parentAnchor.frame)) {
            try TreeKinematicsEvaluator().evaluate(tree, state: JointFixtures.state(q: [], v: [], time: 1, anchors: [sample]), policy: JointFixtures.policy())
        }
    }

    @Test func movingChildAnchorInversionAndIdentityComposition() throws {
        let frame = FrameMotion(pose: RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: Double.pi / 2), translation: try Vector3(2, 3, 0)),
            velocity: SpatialMotion(angular: try Vector3(0, 0, 4), linear: try Vector3(5, 6, 0)),
            acceleration: SpatialMotion(angular: try Vector3(0, 0, 7), linear: try Vector3(8, 9, 0)))
        let composer: any FrameMotionComposing = FrameMotionComposer()
        let inverse = try composer.inverted(frame), identity = try composer.composed(parent: frame, relative: inverse)
        #expect(try identity.pose.translation.magnitude() < 1e-12)
        #expect(try identity.velocity.angular.magnitude() < 1e-12)
        #expect(try identity.velocity.linear.magnitude() < 1e-12)
        #expect(try identity.acceleration.angular.magnitude() < 1e-12)
        #expect(try identity.acceleration.linear.magnitude() < 1e-12)
        let root = try JointFixtures.body("root"), child = try JointFixtures.body("child")
        let joint = try JointFixtures.joint("moving-child", parent: "root", child: "child", specification: .fixed, childPlacement: .prescribed)
        let tree = try JointFixtures.tree(bodies: [root, child], joints: [joint])
        let sample = try PrescribedAnchorState(frame: joint.childAnchor.frame, time: 0, motion: frame)
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: JointFixtures.state(q: [], v: [], anchors: [sample]), policy: JointFixtures.policy())
        #expect(try snapshot.body(child.id).motion == inverse)
    }

    @Test func planarFloatingRootAndOutOfPlaneRejection() throws {
        let root = try JointFixtures.body("root", planar: true)
        let tree = try JointFixtures.tree(bodies: [root], joints: [], base: .planarFloating)
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: JointFixtures.state(q: [2, 3, 0.7], v: [4, 5, 6], acceleration: [7, 8, 9]), policy: JointFixtures.policy())
        #expect(try snapshot.body(root.id).motion.pose.translation == Vector3(2, 3, 0))
        #expect(try snapshot.body(root.id).motion.velocity.linear == Vector3(4, 5, 0))
        #expect(try snapshot.body(root.id).motion.acceleration.angular == Vector3(0, 0, 9))
        #expect(throws: JointError.nonplanarGeometry) { try JointFixtures.tree(bodies: [root], joints: [], base: .spatialFloating) }
        let child = try JointFixtures.body("child", planar: true)
        let invalid = try JointFixtures.joint("invalid", parent: "root", child: "child", specification: .prismatic(axis: .unitZ))
        #expect(throws: JointError.nonplanarGeometry) { try JointFixtures.tree(bodies: [root, child], joints: [invalid]) }
    }
}
