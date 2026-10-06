/// Closed measured/fitted envelope for the selected instantaneous rigid planar model.
public struct TireCalibrationDomain: Equatable, Sendable {
    public let minimumNormalLoad: Double
    public let maximumNormalLoad: Double
    public let minimumRadius: Double
    public let maximumRadius: Double
    public let minimumAbsoluteLongitudinalSpeed: Double
    public let maximumAbsoluteLongitudinalSpeed: Double
    public let maximumAbsoluteLateralSpeed: Double
    public let maximumAbsoluteSpin: Double
    public let maximumAbsoluteSlipRatio: Double
    public let maximumAbsoluteLateralSlipTangent: Double

    public init(minimumNormalLoad: Double, maximumNormalLoad: Double,
                minimumRadius: Double, maximumRadius: Double,
                minimumAbsoluteLongitudinalSpeed: Double, maximumAbsoluteLongitudinalSpeed: Double,
                maximumAbsoluteLateralSpeed: Double, maximumAbsoluteSpin: Double,
                maximumAbsoluteSlipRatio: Double, maximumAbsoluteLateralSlipTangent: Double) throws(TireLawError) {
        guard minimumNormalLoad.isFinite, minimumNormalLoad > 0,
              maximumNormalLoad.isFinite, maximumNormalLoad >= minimumNormalLoad,
              minimumRadius.isFinite, minimumRadius > 0,
              maximumRadius.isFinite, maximumRadius >= minimumRadius,
              minimumAbsoluteLongitudinalSpeed.isFinite, minimumAbsoluteLongitudinalSpeed > 0,
              maximumAbsoluteLongitudinalSpeed.isFinite,
              maximumAbsoluteLongitudinalSpeed >= minimumAbsoluteLongitudinalSpeed,
              maximumAbsoluteLateralSpeed.isFinite, maximumAbsoluteLateralSpeed >= 0,
              maximumAbsoluteSpin.isFinite, maximumAbsoluteSpin >= 0,
              maximumAbsoluteSlipRatio.isFinite, maximumAbsoluteSlipRatio >= 0,
              maximumAbsoluteLateralSlipTangent.isFinite, maximumAbsoluteLateralSlipTangent >= 0 else {
            throw .invalidCalibration
        }
        self.minimumNormalLoad = minimumNormalLoad; self.maximumNormalLoad = maximumNormalLoad
        self.minimumRadius = minimumRadius; self.maximumRadius = maximumRadius
        self.minimumAbsoluteLongitudinalSpeed = minimumAbsoluteLongitudinalSpeed
        self.maximumAbsoluteLongitudinalSpeed = maximumAbsoluteLongitudinalSpeed
        self.maximumAbsoluteLateralSpeed = maximumAbsoluteLateralSpeed
        self.maximumAbsoluteSpin = maximumAbsoluteSpin
        self.maximumAbsoluteSlipRatio = maximumAbsoluteSlipRatio
        self.maximumAbsoluteLateralSlipTangent = maximumAbsoluteLateralSlipTangent
    }
}
