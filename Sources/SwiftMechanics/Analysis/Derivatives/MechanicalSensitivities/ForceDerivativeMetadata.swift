public struct ForceDerivativeMetadata: Equatable, Sendable {
    public let revision: UInt64
    public let coordinateCount: Int
    public let parameterCount: Int
    public let parameterIDs: [UInt64]
    public let parameterDimensions: [PhysicalDimension]
    public let availability: ForceDerivativeAvailability
    public init(revision: UInt64, coordinateCount: Int, parameterIDs: [UInt64], parameterDimensions: [PhysicalDimension], availability: ForceDerivativeAvailability) {
        self.revision=revision; self.coordinateCount=coordinateCount; self.parameterCount=parameterIDs.count
        self.parameterIDs=parameterIDs; self.parameterDimensions=parameterDimensions; self.availability=availability
    }
}
