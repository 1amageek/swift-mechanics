public struct NonlinearMechanismState: Sendable {
    public let point: [Double]
    public let acceleration: ConstrainedMotion
    public let velocityProjection: ConstrainedMotion
    public let positionResidual: Double
    public let velocityResidual: Double
    public let positionCorrection: Double
    public let stageChartCorrection: Double?
    public let positionProjectionEnergyChange: Double?
    public let kineticEnergy: Double
    internal init(point:[Double], acceleration:ConstrainedMotion, velocity:ConstrainedMotion, positionResidual:Double,
                  velocityResidual:Double, correction:Double, kineticEnergy:Double, chartCorrection:Double? = nil, positionEnergyChange:Double? = nil) {
        self.point=point;self.acceleration=acceleration;velocityProjection=velocity;self.positionResidual=positionResidual
        self.velocityResidual=velocityResidual;positionCorrection=correction;self.kineticEnergy=kineticEnergy;stageChartCorrection=chartCorrection;positionProjectionEnergyChange=positionEnergyChange
    }
}
