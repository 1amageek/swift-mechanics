@testable import SwiftMechanics
import Testing

@Suite struct CoordinateTests {
    @Test func countsAndRoundTrip() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        #expect(BaseLayout.fixed.positionCount == 0 && BaseLayout.fixed.velocityCount == 0)
        #expect(BaseLayout.planarFloating.positionCount == 3 && BaseLayout.planarFloating.velocityCount == 3)
        #expect(BaseLayout.spatialFloating.positionCount == 7 && BaseLayout.spatialFloating.velocityCount == 6)
        #expect(try BaseLayout.fixed.decode(BaseLayout.fixed.encode(.fixed), quaternionTolerance: tolerance) == .fixed)
        let planar = BaseState.planar(pose: try PlanarPose(x: 2, y: 3, angle: 0.7), worldVelocityX: 4, worldVelocityY: 5, angularVelocityZ: 6)
        #expect(try BaseLayout.planarFloating.decode(BaseLayout.planarFloating.encode(planar), quaternionTolerance: tolerance) == planar)
        let pose = RigidTransform(rotation: try UnitQuaternion(axis: Vector3(1, 2, 3), angle: 0.8), translation: try Vector3(2, 3, 4))
        let spatial = BaseState.spatial(pose: pose, worldLinearVelocity: try Vector3(5, 6, 7), bodyAngularVelocity: try Vector3(8, 9, 10))
        let coordinates = try BaseLayout.spatialFloating.encode(spatial)
        #expect(coordinates.q.count == 7 && coordinates.v == [5, 6, 7, 8, 9, 10])
        let decoded = try BaseLayout.spatialFloating.decode(coordinates, quaternionTolerance: tolerance)
        guard case .spatial(let recovered, let linear, let angular) = decoded else { Issue.record("Incorrect spatial state"); return }
        #expect(try recovered.transforming(point: .unitX).subtracting(pose.transforming(point: .unitX)).magnitude() < 1e-12)
        #expect(try linear == Vector3(5, 6, 7))
        #expect(try angular == Vector3(8, 9, 10))
    }

    @Test func invalidCountsDimensionQuaternionAndFiniteValues() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        #expect(throws: ModelError.invalidLayout) { try BaseLayout.fixed.encode(.planar(pose: PlanarPose(x: 0, y: 0, angle: 0), worldVelocityX: 0, worldVelocityY: 0, angularVelocityZ: 0)) }
        #expect(throws: ModelError.invalidLayout) { try BaseLayout.spatialFloating.decode(BaseCoordinates(q: [0], v: []), quaternionTolerance: tolerance) }
        #expect(throws: ModelError.invalidQuaternion) { try BaseLayout.spatialFloating.decode(BaseCoordinates(q: [0, 0, 0, 0, 0, 0, 0], v: [0, 0, 0, 0, 0, 0]), quaternionTolerance: tolerance) }
        #expect(throws: ModelError.invalidQuaternion) { try BaseLayout.spatialFloating.decode(BaseCoordinates(q: [0, 0, 0, 2, 0, 0, 0], v: [0, 0, 0, 0, 0, 0]), quaternionTolerance: tolerance) }
        #expect(throws: ModelError.nonFiniteCoordinates) { try BaseCoordinates(q: [.nan], v: []) }
        #expect(throws: ModelError.nonFiniteCoordinates) { try PlanarPose(x: 0, y: 0, angle: .infinity) }
        #expect(throws: ModelError.nonFiniteCoordinates) { try BaseLayout.planarFloating.encode(.planar(pose: PlanarPose(x: 0, y: 0, angle: 0), worldVelocityX: .infinity, worldVelocityY: 0, angularVelocityZ: 0)) }
    }
}
