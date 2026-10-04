public struct InertiaTransformer: InertiaTransforming, Sendable {
    public init() {}

    public func rotated(_ inertia: Matrix3, by rotation: UnitQuaternion) throws(CoreError) -> Matrix3 {
        let matrix = try rotation.matrix()
        return try matrix.multiplied(by: inertia).multiplied(by: matrix.transposed())
    }

    /// Applies the parallel-axis law. Physical inertia validation belongs to the model owner.
    public func shifted(_ inertia: Matrix3, mass: Double, displacement: Vector3) throws(CoreError) -> Matrix3 {
        guard mass.isFinite, mass >= 0 else { throw .invalidMass }
        let r = displacement
        let radiusSquared = try r.dot(r)
        let outer = try Matrix3(
            r.x * r.x, r.x * r.y, r.x * r.z,
            r.y * r.x, r.y * r.y, r.y * r.z,
            r.z * r.x, r.z * r.y, r.z * r.z
        )
        let shift = try Matrix3.identity.scaled(by: radiusSquared).subtracting(outer).scaled(by: mass)
        return try inertia.adding(shift)
    }
}
