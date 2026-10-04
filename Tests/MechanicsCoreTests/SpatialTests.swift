import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SpatialTests {
    @Test func transformPointCompositionAndInverse() throws {
        let a = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: .pi / 2), translation: try Vector3(3, 4, 0))
        let b = RigidTransform(rotation: try UnitQuaternion(axis: .unitX, angle: 0.3), translation: try Vector3(1, 2, 3))
        let point = try Vector3(4, -2, 5)
        let composed = try a.composed(with: b)
        #expect(try composed.transforming(point: point).subtracting(a.transforming(point: b.transforming(point: point))).magnitude() < 1e-12)
        #expect(try a.inverted().transforming(point: a.transforming(point: point)).subtracting(point).magnitude() < 1e-12)
        #expect(try a.transforming(direction: .unitX).subtracting(.unitY).magnitude() < 1e-15)
    }

    @Test func originShiftPreservesVirtualPowerAndMoments() throws {
        let transform: any SpatialTransforming = RigidTransform(
            rotation: try UnitQuaternion(axis: try Vector3(1, 2, 3), angle: 0.7), translation: try Vector3(3, -2, 5)
        )
        let motion = SpatialMotion(angular: try Vector3(1, 2, -3), linear: try Vector3(-2, 3, 4))
        let wrench = SpatialWrench(torque: try Vector3(2, -1, 4), force: try Vector3(-5, 6, 2))
        #expect(abs(try transform.transforming(wrench: wrench).power(against: transform.transforming(motion: motion)) - wrench.power(against: motion)) < 1e-12)
        let shift = RigidTransform(rotation: .identity, translation: .unitX)
        let shifted = try shift.transforming(wrench: SpatialWrench(torque: .zero, force: .unitY))
        #expect(shifted.torque == .unitZ)
        let spin = SpatialMotion(angular: .unitZ, linear: .zero)
        #expect(try spin.velocity(at: .unitX) == .unitY)
    }

    @Test func inertiaRotatesAndUsesParallelAxisLaw() throws {
        let service: any InertiaTransforming = InertiaTransformer()
        let inertia = try Matrix3(1, 0, 0, 0, 2, 0, 0, 0, 3)
        let rotated = try service.rotated(inertia, by: UnitQuaternion(axis: .unitZ, angle: .pi / 2))
        #expect(abs(rotated.m00 - 2) < 1e-14)
        #expect(abs(rotated.m11 - 1) < 1e-14)
        #expect(abs(rotated.m22 - 3) < 1e-14)
        let shifted = try service.shifted(inertia, mass: 2, displacement: Vector3(3, 4, 0))
        let expected = try Matrix3(33, -24, 0, -24, 20, 0, 0, 0, 53)
        #expect(shifted == expected)
        #expect(throws: CoreError.invalidMass) { try service.shifted(inertia, mass: -1, displacement: .zero) }
    }
}
