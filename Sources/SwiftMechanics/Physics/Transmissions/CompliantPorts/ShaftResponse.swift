
public struct ShaftResponse: Sendable {
    public let binding: TransmissionPortBinding
    public let inertiaCoefficient: Double
    public let requiredInertialEffort: Double
    public let kineticEnergy: Double
    public let passive: ScalarJointResponse
    public let passiveAxialTorque: Vector3
}
