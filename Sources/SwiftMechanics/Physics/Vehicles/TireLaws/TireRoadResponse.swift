public struct TireRoadResponse: Sendable {
    public let sample: TireRoadSample
    public let frame: TireRoadFrame
    public let calibration: TireBrushCalibration
    public let slip: TireSlip
    public let tangentialPointLoad: FramedPointLoad
    public let wheelCenterWrench: SpatialWrench
    public let roadContactWrench: SpatialWrench
    public let longitudinalForce: Double
    public let lateralForce: Double
    public let rollingMoment: Double
    public let isForceSaturated: Bool
    public let power: TirePowerDiagnostics

    internal init(sample: TireRoadSample, frame: TireRoadFrame, calibration: TireBrushCalibration,
                  slip: TireSlip, tangentialPointLoad: FramedPointLoad, wheelCenterWrench: SpatialWrench,
                  roadContactWrench: SpatialWrench, longitudinalForce: Double, lateralForce: Double,
                  rollingMoment: Double, isForceSaturated: Bool, power: TirePowerDiagnostics) {
        self.sample = sample; self.frame = frame; self.calibration = calibration; self.slip = slip
        self.tangentialPointLoad = tangentialPointLoad; self.wheelCenterWrench = wheelCenterWrench
        self.roadContactWrench = roadContactWrench; self.longitudinalForce = longitudinalForce
        self.lateralForce = lateralForce; self.rollingMoment = rollingMoment
        self.isForceSaturated = isForceSaturated; self.power = power
    }
}
