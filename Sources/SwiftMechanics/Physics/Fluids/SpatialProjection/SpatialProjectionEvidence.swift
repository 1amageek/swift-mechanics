public struct SpatialProjectionEvidence: Equatable, Sendable {
    public let maximumDivergence:Double
    public let maximumPressureResidual:Double
    public let maximumCorrectionForceResidual:Double
    public let meanMomentumResidualX:Double
    public let meanMomentumResidualY:Double
    public let meanMomentumResidualZ:Double
    public let kineticBefore:Double
    public let kineticAfter:Double
    public let projectionLoss:Double
    public let pressureResidualWork:Double
    public let energyDefect:Double
}
