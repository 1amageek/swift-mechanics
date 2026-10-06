public struct InertialParameterProduct: Sendable {
    public let bindings: [RigidInertialParameterBinding]
    public let directions: [RigidInertialParameterDirection]
    public let mechanics: MechanicalTangent
    /// Actual inverse dynamics at the supplied fixed generalized acceleration.
    public let primalInverse: DynamicsSolution
    public let primalEnergy: MechanicalEnergy
    public let requiredDriveDirection: [Double]
    /// Dimensionless differentiated original body-equation residual after S_i/E scaling.
    public let originalResidual: Double
    public let originalThreshold: Double
}
