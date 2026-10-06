public struct InertialParameterAccelerationProduct: Sendable {
    public let bindings: [RigidInertialParameterBinding]
    public let directions: [RigidInertialParameterDirection]
    /// Actual primal forward solution and accepted differentiated original physical residual.
    public let dynamics: AccelerationTangent
}
