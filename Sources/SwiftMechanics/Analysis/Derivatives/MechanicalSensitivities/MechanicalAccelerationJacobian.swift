public struct MechanicalAccelerationJacobian: Sendable {
    public let revision: UInt64
    public let variable: MechanicalJacobianVariable
    public let coordinateCount: Int
    /// Row-major physical acceleration/local-chart variable Jacobian.
    public let values: [Double]
    public let maximumOriginalResidual: Double
}
