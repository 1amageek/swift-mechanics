import MechanicsDynamics
public struct AccelerationTangent: Sendable {
    public let mechanics: MechanicalTangent
    public let primal: DynamicsSolution
    public let acceleration: [Double]
    /// Dimensionless differentiated original Newton-Euler residual after S_i/E scaling.
    public let originalResidual: Double
    public let originalThreshold: Double
}
