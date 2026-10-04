public struct NonlinearMechanismState: Sendable {
    public let point: [Double]
    public let acceleration: ConstrainedMotion
    public let velocityProjection: ConstrainedMotion
    public let positionResidual: Double
    public let velocityResidual: Double
    public let positionCorrection: Double
    public let kineticEnergy: Double
    internal init(point:[Double], acceleration:ConstrainedMotion, velocity:ConstrainedMotion, positionResidual:Double,
                  velocityResidual:Double, correction:Double, kineticEnergy:Double) {
        self.point=point;self.acceleration=acceleration;velocityProjection=velocity;self.positionResidual=positionResidual
        self.velocityResidual=velocityResidual;positionCorrection=correction;self.kineticEnergy=kineticEnergy
    }
}
