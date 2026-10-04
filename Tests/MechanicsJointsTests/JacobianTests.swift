@testable import SwiftMechanics
import Testing

@Suite struct JacobianTests {
    private func serialTree() throws -> KinematicTree {
        let root = try JointFixtures.body("root"), first = try JointFixtures.body("first"), second = try JointFixtures.body("second")
        let offset = RigidTransform(rotation: try UnitQuaternion(axis: .unitX, angle: 0.4), translation: try Vector3(0.7, -0.3, 0.2))
        let hinge = try JointFixtures.joint("hinge", parent: "root", child: "first", specification: .revolute(axis: .unitZ), childPlacement: .fixed(offset))
        let slider = try JointFixtures.joint("slider", parent: "first", child: "second", specification: .prismatic(axis: .unitY))
        return try JointFixtures.tree(bodies: [root, first, second], joints: [hinge, slider], base: .spatialFloating)
    }

    @Test func centralDirectionalGeometricAndPointJacobians() throws {
        let tree = try serialTree(), body = try JointFixtures.id(.body, "second")
        let rotation = try UnitQuaternion(axis: Vector3(1, 2, 3), angle: 0.6)
        let state = try JointFixtures.state(q: [1, 2, 3, rotation.w, rotation.x, rotation.y, rotation.z, 0.7, -0.4],
                                            v: [0.2, -0.3, 0.5, 0.4, -0.7, 0.6, 1.2, -0.8])
        let evaluator: any TreeKinematicsComputing = TreeKinematicsEvaluator(), calculator: any KinematicJacobianComputing = KinematicJacobianCalculator()
        let policy = try JointFixtures.policy(), epsilon = 1e-6
        let snapshot = try evaluator.evaluate(tree, state: state, policy: policy)
        let plus = try evaluator.evaluate(tree, state: JointFixtures.displaced(tree, state: state, step: epsilon), policy: policy)
        let minus = try evaluator.evaluate(tree, state: JointFixtures.displaced(tree, state: state, step: -epsilon), policy: policy)
        let p = try plus.body(body).motion.pose, m = try minus.body(body).motion.pose
        let difference = try p.translation.subtracting(m.translation).scaled(by: 1 / (2 * epsilon))
        let angularDifference = try p.rotation.multiplied(by: m.rotation.conjugated()).rotationVector().scaled(by: 1 / (2 * epsilon))
        let jacobian = try calculator.geometric(body: body, snapshot: snapshot)
        let product = try jacobian.applying(state.v[...])
        #expect(try product.linear.subtracting(difference).magnitude() < 1e-8)
        #expect(try product.angular.subtracting(angularDifference).magnitude() < 1e-8)
        let local = try Vector3(0.3, -0.2, 0.5)
        let pointJacobian = try calculator.point(body: body, bodyLocalPoint: local, snapshot: snapshot)
        let pointDifference = try p.transforming(point: local).subtracting(m.transforming(point: local)).scaled(by: 1 / (2 * epsilon))
        #expect(try pointJacobian.applying(state.v[...]).subtracting(pointDifference).magnitude() < 1e-8)
        #expect(try snapshot.body(body).motion.velocity.linear.subtracting(product.linear).magnitude() < 1e-12)
        #expect(state.q[0] == 1 && state.v[7] == -0.8)
    }

    @Test func jacobianBiasFromIndependentVelocityDifference() throws {
        let tree = try serialTree(), body = try JointFixtures.id(.body, "second")
        let rotation = try UnitQuaternion(axis: .unitY, angle: 0.3)
        let state = try JointFixtures.state(q: [1, 2, 3, rotation.w, rotation.x, rotation.y, rotation.z, 0.7, 0.4],
                                            v: [0.2, -0.3, 0.5, 0.4, -0.7, 0.6, 1.2, -0.8])
        let evaluator = TreeKinematicsEvaluator(), policy = try JointFixtures.policy(), epsilon = 1e-6
        let snapshot = try evaluator.evaluate(tree, state: state, policy: policy)
        let plus = try evaluator.evaluate(tree, state: JointFixtures.displaced(tree, state: state, step: epsilon), policy: policy)
        let minus = try evaluator.evaluate(tree, state: JointFixtures.displaced(tree, state: state, step: -epsilon), policy: policy)
        let a = try plus.body(body).motion.velocity, b = try minus.body(body).motion.velocity
        let angular = try a.angular.subtracting(b.angular).scaled(by: 1 / (2 * epsilon))
        let linear = try a.linear.subtracting(b.linear).scaled(by: 1 / (2 * epsilon))
        let bias = try snapshot.body(body).accelerationBias
        #expect(try angular.subtracting(bias.angular).magnitude() < 1e-8)
        #expect(try linear.subtracting(bias.linear).magnitude() < 1e-8)
        let point = try Vector3(0.2, 0.3, -0.1), calculator = KinematicJacobianCalculator()
        let pointPlus = try calculator.pointMotion(body: body, bodyLocalPoint: point, snapshot: plus)
        let pointMinus = try calculator.pointMotion(body: body, bodyLocalPoint: point, snapshot: minus)
        let pointExpected = try pointPlus.velocity.subtracting(pointMinus.velocity).scaled(by: 1 / (2 * epsilon))
        let pointActual = try calculator.pointMotion(body: body, bodyLocalPoint: point, snapshot: snapshot)
        #expect(try pointExpected.subtracting(pointActual.accelerationBias).magnitude() < 1e-8)
    }

    @Test func geometricSpatialAndPointVirtualPower() throws {
        let tree = try serialTree(), body = try JointFixtures.id(.body, "second")
        let rotation = try UnitQuaternion(axis: Vector3(1, 2, 3), angle: 0.6)
        let state = try JointFixtures.state(q: [1, 2, 3, rotation.w, rotation.x, rotation.y, rotation.z, 0.7, -0.4],
                                            v: [0.2, -0.3, 0.5, 0.4, -0.7, 0.6, 1.2, -0.8])
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: state, policy: JointFixtures.policy())
        let calculator = KinematicJacobianCalculator()
        let wrench = SpatialWrench(torque: try Vector3(0.7, -1.2, 2.3), force: try Vector3(4, -3, 2))
        let geometric = try calculator.geometric(body: body, snapshot: snapshot)
        let loads = try geometric.transposed(against: wrench)
        let generalizedPower = zip(loads, state.v).reduce(0) { $0 + $1.0 * $1.1 }
        let power = try wrench.power(against: geometric.applying(state.v[...]))
        #expect(abs(generalizedPower - power) < 1e-12)
        let position = try snapshot.body(body).motion.pose.translation
        let spatialWrench = SpatialWrench(torque: try wrench.torque.adding(position.cross(wrench.force)), force: wrench.force)
        let spatial = try calculator.spatial(body: body, snapshot: snapshot)
        let spatialLoads = try spatial.transposed(against: spatialWrench)
        for index in loads.indices { #expect(abs(spatialLoads[index] - loads[index]) < 1e-12) }
        #expect(abs(try spatialWrench.power(against: spatial.applying(state.v[...])) - power) < 1e-12)
        let local = try Vector3(0.3, -0.2, 0.5), point = try calculator.point(body: body, bodyLocalPoint: local, snapshot: snapshot)
        let pointLoads = try point.transposed(against: wrench.force)
        let pointPower = zip(pointLoads, state.v).reduce(0) { $0 + $1.0 * $1.1 }
        #expect(abs(try wrench.force.dot(point.applying(state.v[...])) - pointPower) < 1e-12)
        #expect(geometric.convention == .geometricAtBodyOrigin && spatial.convention == .spatialAtWorldOrigin)
        #expect(geometric.referenceFrame == tree.worldFrame && point.referenceFrame == tree.worldFrame)
    }

    @Test func prescribedDriftPowerAndPointAcceleration() throws {
        let root = try JointFixtures.body("root"), child = try JointFixtures.body("child")
        let joint = try JointFixtures.joint("moving", parent: "root", child: "child", specification: .prismatic(axis: .unitX), parentPlacement: .prescribed)
        let tree = try JointFixtures.tree(bodies: [root, child], joints: [joint])
        let anchor = try PrescribedAnchorState(frame: joint.parentAnchor.frame, time: 0,
            motion: FrameMotion(pose: .identity, velocity: SpatialMotion(angular: Vector3(0, 0, 3), linear: Vector3(4, 0, 0)),
                                acceleration: SpatialMotion(angular: .zero, linear: Vector3(6, 0, 0))))
        let state = try JointFixtures.state(q: [2], v: [5], anchors: [anchor])
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: state, policy: JointFixtures.policy())
        let calculator = KinematicJacobianCalculator(), jacobian = try calculator.geometric(body: child.id, snapshot: snapshot)
        let generalizedMotion = try jacobian.applying(state.v[...]), actual = try snapshot.body(child.id).motion.velocity
        #expect(try generalizedMotion.linear.adding(jacobian.prescribedDrift.linear).subtracting(actual.linear).magnitude() < 1e-12)
        let wrench = SpatialWrench(torque: .unitZ, force: .unitX)
        let virtualPower = try wrench.power(against: generalizedMotion), driftPower = try wrench.power(against: jacobian.prescribedDrift)
        #expect(abs(try wrench.power(against: actual) - virtualPower - driftPower) < 1e-12)
        let point = try calculator.pointMotion(body: child.id, bodyLocalPoint: .unitX, snapshot: snapshot)
        #expect(try point.velocity.subtracting(Vector3(9, 9, 0)).magnitude() < 1e-12)
        #expect(try point.acceleration.subtracting(Vector3(-21, 30, 0)).magnitude() < 1e-12)
        #expect(try point.accelerationBias == point.acceleration)
    }
}
