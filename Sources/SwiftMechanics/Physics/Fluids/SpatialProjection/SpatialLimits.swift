public struct SpatialLimits: Equatable, Sendable {
    public let maximumCells:Int
    public let maximumMetadataBytes:Int
    public let maximumSpeed:Double
    public let maximumPressure:Double
    public let maximumAcceleration:Double
    public let maximumStep:Double
    public init(maximumCells:Int,maximumMetadataBytes:Int,maximumSpeed:Double,maximumPressure:Double,
                maximumAcceleration:Double,maximumStep:Double) throws(SpatialFluidError) {
        guard maximumCells >= 27,maximumMetadataBytes >= 0,maximumSpeed.isFinite,maximumSpeed > 0,
              maximumPressure.isFinite,maximumPressure > 0,maximumAcceleration.isFinite,maximumAcceleration > 0,
              maximumStep.isFinite,maximumStep > 0 else { throw .invalidInput }
        self.maximumCells=maximumCells;self.maximumMetadataBytes=maximumMetadataBytes
        self.maximumSpeed=maximumSpeed;self.maximumPressure=maximumPressure
        self.maximumAcceleration=maximumAcceleration;self.maximumStep=maximumStep
    }
}
