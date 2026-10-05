public struct TerrainCalibrationDomain: Equatable, Sendable {
    public let minimumFootprintWidth: Double
    public let maximumFootprintWidth: Double
    public let maximumSinkage: Double
    public let maximumShearTravel: Double
    public let maximumPressure: Double
    public let maximumNormalLoad: Double
    public let maximumTangentialSpeed: Double
    public let maximumNormalSpeed: Double
    public let minimumTimeStep: Double
    public let maximumTimeStep: Double

    public init(minimumFootprintWidth: Double, maximumFootprintWidth: Double, maximumSinkage: Double,
                maximumShearTravel: Double, maximumPressure: Double, maximumNormalLoad: Double,
                maximumTangentialSpeed: Double, maximumNormalSpeed: Double,
                minimumTimeStep: Double, maximumTimeStep: Double) throws(TerrainLawError) {
        guard minimumFootprintWidth.isFinite, minimumFootprintWidth > 0,
              maximumFootprintWidth.isFinite, maximumFootprintWidth >= minimumFootprintWidth,
              maximumSinkage.isFinite, maximumSinkage > 0,
              maximumShearTravel.isFinite, maximumShearTravel > 0,
              maximumPressure.isFinite, maximumPressure > 0,
              maximumNormalLoad.isFinite, maximumNormalLoad > 0,
              maximumTangentialSpeed.isFinite, maximumTangentialSpeed >= 0,
              maximumNormalSpeed.isFinite, maximumNormalSpeed >= 0,
              minimumTimeStep.isFinite, minimumTimeStep > 0,
              maximumTimeStep.isFinite, maximumTimeStep >= minimumTimeStep else { throw .invalidCalibration }
        self.minimumFootprintWidth = minimumFootprintWidth; self.maximumFootprintWidth = maximumFootprintWidth
        self.maximumSinkage = maximumSinkage; self.maximumShearTravel = maximumShearTravel
        self.maximumPressure = maximumPressure; self.maximumNormalLoad = maximumNormalLoad
        self.maximumTangentialSpeed = maximumTangentialSpeed; self.maximumNormalSpeed = maximumNormalSpeed
        self.minimumTimeStep = minimumTimeStep; self.maximumTimeStep = maximumTimeStep
    }
}
