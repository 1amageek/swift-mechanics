public protocol RotationIntegrating: Sendable {
    func integratingBodyAngularVelocity(_ velocity: Vector3, timeStep: Double) throws(CoreError) -> UnitQuaternion
    func integratingWorldAngularVelocity(_ velocity: Vector3, timeStep: Double) throws(CoreError) -> UnitQuaternion
    func bodyRate(for velocity: Vector3) throws(CoreError) -> QuaternionRate
}
