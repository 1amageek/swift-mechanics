public protocol InertiaTransforming: Sendable {
    func rotated(_ inertia: Matrix3, by rotation: UnitQuaternion) throws(CoreError) -> Matrix3
    func shifted(_ inertia: Matrix3, mass: Double, displacement: Vector3) throws(CoreError) -> Matrix3
}
