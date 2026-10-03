import Testing
import MechanicsCore
import MechanicsModel
@testable import MechanicsJoints

@Suite struct ManifoldTests {
    @Test func standardJointCountsAndMotionColumns() throws {
        let rotation = try UnitQuaternion(axis: Vector3(1, 2, 3), angle: 3.7)
        let quaternion = [rotation.w, rotation.x, rotation.y, rotation.z]
        let fixtures: [(JointSpecification, [Double], Int, Int)] = [
            (.fixed, [], 0, 0), (.revolute(axis: .unitZ), [2.7], 1, 1), (.prismatic(axis: .unitX), [-3], 1, 1),
            (.spherical, quaternion, 4, 3), (.universal(firstAxis: .unitX, secondAxis: .unitY), [2.3, -1.9], 2, 2),
            (.cylindrical(axis: .unitZ), [0.7, -2.8], 2, 2),
            (.planar(firstTranslationAxis: .unitX, secondTranslationAxis: .unitY), [1.2, -2.3, 3.4], 3, 3),
            (.screw(axis: .unitZ, pitchMetersPerRadian: -0.25), [0.8], 1, 1), (.sixDOF, [1, 2, 3] + quaternion, 7, 6)]
        let evaluator: any JointMotionEvaluating = JointMotionEvaluator(), policy = try JointFixtures.policy()
        for (specification, q, qCount, vCount) in fixtures {
            let manifold = try JointManifold(specification)
            #expect(manifold.positionCount == qCount && manifold.velocityCount == vCount)
            let v = (0..<vCount).map { Double($0 + 1) * 0.3 }, a = [Double](repeating: 0, count: vCount)
            let result = try evaluator.evaluate(manifold, q: q[...], v: v[...], acceleration: a[...], policy: policy)
            let product = try result.subspace.applying(v[...])
            #expect(try product.angular.subtracting(result.frameMotion.velocity.angular).magnitude() < 1e-12)
            #expect(try product.linear.subtracting(result.frameMotion.velocity.linear).magnitude() < 1e-12)
            #expect(result.coordinateRate.count == qCount)
        }
    }

    @Test func allowedAndBlockedWrenchDirections() throws {
        let evaluator = JointMotionEvaluator(), policy = try JointFixtures.policy()
        let fixtures: [(JointSpecification, [Double], SpatialWrench)] = [
            (.revolute(axis: .unitZ), [0.4], SpatialWrench(torque: .unitX, force: .unitY)),
            (.prismatic(axis: .unitX), [0.4], SpatialWrench(torque: .unitZ, force: .unitY)),
            (.cylindrical(axis: .unitZ), [0.4, 0.7], SpatialWrench(torque: .unitX, force: .unitY)),
            (.planar(firstTranslationAxis: .unitX, secondTranslationAxis: .unitY), [0.4, 0.7, 1.2], SpatialWrench(torque: .unitX, force: .unitZ)),
            (.spherical, [1, 0, 0, 0], SpatialWrench(torque: .zero, force: .unitX)),
            (.screw(axis: .unitZ, pitchMetersPerRadian: -0.25), [0.7], SpatialWrench(torque: try Vector3(0, 0, 0.25), force: .unitZ))]
        for (specification, q, blocked) in fixtures {
            let manifold = try JointManifold(specification), v = [Double](repeating: 1, count: manifold.velocityCount)
            let zero = [Double](repeating: 0, count: v.count)
            let result = try evaluator.evaluate(manifold, q: q[...], v: v[...], acceleration: zero[...], policy: policy)
            #expect(try result.subspace.transposed(against: blocked).allSatisfy { abs($0) < 1e-12 })
            #expect(abs(try blocked.power(against: result.frameMotion.velocity)) < 1e-12)
        }
        let fixed = try evaluator.evaluate(JointManifold(.fixed), q: [][...], v: [][...], acceleration: [][...], policy: policy)
        #expect(fixed.subspace.columns.isEmpty && fixed.frameMotion.pose == .identity)
        let revolute = try evaluator.evaluate(JointManifold(.revolute(axis: .unitZ)), q: [0][...], v: [2][...], acceleration: [0][...], policy: policy)
        #expect(try revolute.subspace.transposed(against: SpatialWrench(torque: .unitZ, force: .zero)) == [1])
    }

    @Test func signedScrewAndCustomReconstruction() throws {
        let evaluator = JointMotionEvaluator(), policy = try JointFixtures.policy()
        let screw = try JointManifold(.screw(axis: .unitZ, pitchMetersPerRadian: -0.2))
        let result = try evaluator.evaluate(screw, q: [2 * Double.pi][...], v: [3][...], acceleration: [0][...], policy: policy)
        #expect(abs(result.frameMotion.pose.translation.z + 0.4 * Double.pi) < 1e-12)
        let load = SpatialWrench(torque: try Vector3(0, 0, 2), force: try Vector3(0, 0, 5))
        #expect(abs(try load.power(against: result.frameMotion.velocity) - 3) < 1e-12)
        #expect(try result.subspace.transposed(against: load) == [1])
        let standard = try JointManifold(.planar(firstTranslationAxis: .unitX, secondTranslationAxis: .unitY))
        let generic = try JointManifold(.custom(orderedAxes: [JointAxis(kind: .prismatic, direction: .unitX),
            JointAxis(kind: .prismatic, direction: .unitY), JointAxis(kind: .revolute, direction: .unitZ)]))
        let q = [2.0, -1.0, 2.7], v = [0.3, -0.8, 1.2], a = [0.2, 0.4, -0.5]
        let first = try evaluator.evaluate(standard, q: q[...], v: v[...], acceleration: a[...], policy: policy)
        let second = try evaluator.evaluate(generic, q: q[...], v: v[...], acceleration: a[...], policy: policy)
        #expect(first == second)
    }

    @Test func quaternionNAndManifoldDirectionalMotion() throws {
        let evaluator = JointMotionEvaluator(), policy = try JointFixtures.policy()
        let rotation = try UnitQuaternion(axis: Vector3(1, 2, -1), angle: 2.4)
        let q = [rotation.w, rotation.x, rotation.y, rotation.z], v = [0.7, -0.3, 0.8]
        let spherical = try JointManifold(.spherical)
        let evaluation = try evaluator.evaluate(spherical, q: q[...], v: v[...], acceleration: [0, 0, 0][...], policy: policy)
        let dt = 1e-6, reversed = v.map { -$0 }
        let plus = try evaluator.integrating(spherical, q: q[...], v: v[...], timeStep: dt, policy: policy)
        let minus = try evaluator.integrating(spherical, q: q[...], v: reversed[...], timeStep: dt, policy: policy)
        for index in q.indices { #expect(abs((plus[index] - minus[index]) / (2 * dt) - evaluation.coordinateRate[index]) < 1e-9) }
        let negated = q.map { -$0 }
        let equivalent = try evaluator.evaluate(spherical, q: negated[...], v: v[...], acceleration: [0, 0, 0][...], policy: policy)
        #expect(try equivalent.frameMotion.velocity.angular.subtracting(evaluation.frameMotion.velocity.angular).magnitude() < 1e-12)
    }

    @Test func invalidGeometryStateAndChartSingularity() throws {
        let evaluator = JointMotionEvaluator(), policy = try JointFixtures.policy()
        let hugeAxis = try JointAxis(kind: .revolute, direction: Vector3(Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, 0))
        #expect(abs(hugeAxis.direction.x - 1 / 2.0.squareRoot()) < 1e-12)
        #expect(throws: JointError.invalidAxis) { try JointManifold(.revolute(axis: .zero)) }
        #expect(throws: JointError.invalidJointGeometry) { try JointManifold(.universal(firstAxis: .unitX, secondAxis: .unitX)) }
        #expect(throws: JointError.invalidJointGeometry) { try JointManifold(.planar(firstTranslationAxis: .unitX, secondTranslationAxis: .unitX)) }
        #expect(throws: JointError.invalidJointGeometry) { try JointManifold(.screw(axis: .unitZ, pitchMetersPerRadian: .nan)) }
        let rotations = try JointManifold(.custom(orderedAxes: [JointAxis(kind: .revolute, direction: .unitX),
            JointAxis(kind: .revolute, direction: .unitY), JointAxis(kind: .revolute, direction: .unitZ)]))
        #expect(throws: JointError.chartSingularity) {
            try evaluator.evaluate(rotations, q: [0, Double.pi / 2, 0][...], v: [0, 0, 0][...], acceleration: [0, 0, 0][...], policy: policy)
        }
        let duplicate = try JointManifold(.custom(orderedAxes: [JointAxis(kind: .prismatic, direction: .unitX), JointAxis(kind: .prismatic, direction: .unitX)]))
        #expect(throws: JointError.chartSingularity) { try evaluator.evaluate(duplicate, q: [0, 0][...], v: [0, 0][...], acceleration: [0, 0][...], policy: policy) }
        #expect(throws: JointError.invalidCoordinateCount) { try evaluator.evaluate(rotations, q: [0][...], v: [0][...], acceleration: [0][...], policy: policy) }
        #expect(throws: JointError.nonFiniteState) { try evaluator.evaluate(JointManifold(.revolute(axis: .unitZ)), q: [.nan][...], v: [0][...], acceleration: [0][...], policy: policy) }
        #expect(throws: ModelError.invalidQuaternion) { try evaluator.evaluate(JointManifold(.spherical), q: [2, 0, 0, 0][...], v: [0, 0, 0][...], acceleration: [0, 0, 0][...], policy: policy) }
        #expect(throws: JointError.invalidTimeStep) { try evaluator.integrating(JointManifold(.fixed), q: [][...], v: [][...], timeStep: -1, policy: policy) }
    }
}
