public struct SphereAddedInertiaResponse: Equatable, Sendable {
    /// Two representations of the same added inertia; apply only one in an equation of motion.
    public let addedMassMatrix: Matrix3, bodyAccelerationDerivative: Matrix3, fluidAccelerationDerivative: Matrix3
    public let addedInertiaForce: Vector3, pressureGradientForce: Vector3, totalForce: Vector3
    /// Disturbance storage in the uniformly translating medium.
    public let relativeKineticEnergy: Double, relativeKineticEnergyRate: Double
    public let bodyPower: Double, prescribedMediumPower: Double, prescribedPressurePower: Double, powerResidual: Double
}
