public struct NonlinearMechanismState: Sendable {
    public let point: [Double]
    public let acceleration: ConstrainedMotion
    public let velocityProjection: ConstrainedMotion
    public let positionResidual: Double
    public let velocityResidual: Double
    public let positionCorrection: Double
    public let stageChartCorrection: Double?
    public let positionProjectionEnergyChange: Double?
    public let mechanicalEnergy:MechanicalEnergy?
    public let velocityProjectionEnergyChange:Double?
    public let kineticEnergy: Double
    internal init(point:[Double], acceleration:ConstrainedMotion, velocity:ConstrainedMotion, positionResidual:Double,
                  velocityResidual:Double, correction:Double, kineticEnergy:Double, chartCorrection:Double? = nil, positionEnergyChange:Double? = nil, mechanicalEnergy:MechanicalEnergy? = nil, velocityEnergyChange:Double? = nil) {
        self.mechanicalEnergy=mechanicalEnergy;velocityProjectionEnergyChange=velocityEnergyChange;self.point=point;self.acceleration=acceleration;velocityProjection=velocity;self.positionResidual=positionResidual
        self.velocityResidual=velocityResidual;positionCorrection=correction;self.kineticEnergy=kineticEnergy;stageChartCorrection=chartCorrection;positionProjectionEnergyChange=positionEnergyChange
    }
}
