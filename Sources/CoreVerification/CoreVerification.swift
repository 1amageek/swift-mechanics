import MechanicsCore

@main
struct CoreVerification {
    private static func require(_ condition: Bool) throws(CoreError) {
        guard condition else { throw .invalidTolerance }
    }

    static func main() throws(CoreError) {
        let converter: any UnitConverting = SIUnitConverter()
        try require(abs(try converter.convert(180, from: SIUnits.degree, to: SIUnits.radian) - Double.pi) < 1e-14)
        do throws(CoreError) {
            _ = try converter.convert(1, from: SIUnits.metre, to: SIUnits.second)
            throw CoreError.invalidTolerance
        } catch {
            try require(error == .dimensionMismatch)
        }
        let rotation: any RotationIntegrating = UnitQuaternion.identity
        let rate = try rotation.bodyRate(for: .unitZ)
        try require(rate.w == 0 && rate.x == 0 && rate.y == 0 && rate.z == 0.5)
        let q = try rotation.integratingBodyAngularVelocity(.unitZ, timeStep: .pi / 2)
        let world = try rotation.integratingWorldAngularVelocity(.unitZ, timeStep: .pi / 2)
        try require(try q.matrix().subtracting(world.matrix()).maximumMagnitude < 1e-14)
        try require(try q.rotating(.unitX).subtracting(.unitY).magnitude() < 1e-14)
        let transform: any SpatialTransforming = RigidTransform(rotation: q, translation: try Vector3(3, 4, 5))
        try require(try transform.transforming(direction: .unitX).subtracting(.unitY).magnitude() < 1e-14)
        let point = try Vector3(1, 2, 3)
        try require(try transform.inverted().transforming(point: transform.transforming(point: point)).subtracting(point).magnitude() < 1e-12)
        let motion = SpatialMotion(angular: try Vector3(1, -2, 3), linear: try Vector3(4, 1, -2))
        let wrench = SpatialWrench(torque: try Vector3(2, 3, -1), force: try Vector3(1, -4, 2))
        try require(abs(try transform.transforming(wrench: wrench).power(against: transform.transforming(motion: motion)) - wrench.power(against: motion)) < 1e-12)
        let matrix: any Matrix3Operating = try Matrix3(4, 1, 2, 0, 3, -1, 2, 0, 5)
        try require(try matrix.determinant() == 46)
        try require(try matrix.inverted(relativeTolerance: 1e-14).applying(to: matrix.applying(to: point)).subtracting(point).magnitude() < 1e-12)
        let inertia: any InertiaTransforming = InertiaTransformer()
        let rotated = try inertia.rotated(Matrix3(1, 0, 0, 0, 2, 0, 0, 0, 3), by: q)
        try require(abs(rotated.m00 - 2) < 1e-14 && abs(rotated.m11 - 1) < 1e-14)
        let shifted = try inertia.shifted(.identity, mass: 2, displacement: Vector3(3, 4, 0))
        try require(shifted.m00 == 33 && shifted.m11 == 19 && shifted.m22 == 51 && shifted.m01 == -24)
        do throws(CoreError) {
            let invalid: any Matrix3Operating = Matrix3.zero
            _ = try invalid.inverted(relativeTolerance: 0)
            throw CoreError.invalidTolerance
        } catch {
            try require(error == .singularMatrix)
        }
        print("MechanicsCore runtime verification passed: units, frames, rotation, q/v, inertia and power.")
    }
}
