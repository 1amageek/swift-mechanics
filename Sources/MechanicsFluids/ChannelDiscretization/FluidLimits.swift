public struct FluidLimits: Equatable, Sendable {
    public let maximumCells: Int
    public let maximumMetadataBytes: Int
    public let maximumSpeed: Double
    public let maximumPressure: Double
    public let maximumSource: Double
    public let maximumStep: Double
    public init(maximumCells: Int, maximumMetadataBytes: Int, maximumSpeed: Double,
                maximumPressure: Double, maximumSource: Double, maximumStep: Double) throws(FluidError) {
        guard maximumCells > 0, maximumMetadataBytes >= 0,
              maximumSpeed.isFinite, maximumSpeed > 0, maximumPressure.isFinite, maximumPressure > 0,
              maximumSource.isFinite, maximumSource > 0, maximumStep.isFinite, maximumStep > 0 else { throw .invalidInput }
        self.maximumCells=maximumCells; self.maximumMetadataBytes=maximumMetadataBytes
        self.maximumSpeed=maximumSpeed; self.maximumPressure=maximumPressure
        self.maximumSource=maximumSource; self.maximumStep=maximumStep
    }
}
