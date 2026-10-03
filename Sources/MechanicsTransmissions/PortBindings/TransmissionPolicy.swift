public struct TransmissionPolicy: Sendable {
    public let maximumCoordinates: Int
    public let maximumPorts: Int
    public let maximumRelations: Int
    public let expectedLayoutRevision: UInt64
    public let expectedModelRevision: UInt64
    public let geometryTolerance: Double
    public let originalTolerance: Double
    public let powerScale: Double
    public let powerTolerance: Double
    public let isCancelled: @Sendable () -> Bool
    public init(maximumCoordinates: Int, maximumPorts: Int, maximumRelations: Int, expectedLayoutRevision: UInt64, expectedModelRevision: UInt64,
                geometryTolerance: Double, originalTolerance: Double, powerScale: Double, powerTolerance: Double,
                isCancelled: @escaping @Sendable () -> Bool = {false}) throws(TransmissionError) {
        guard maximumCoordinates > 0, maximumPorts > 0, maximumRelations > 0, geometryTolerance.isFinite, geometryTolerance > 0,
              geometryTolerance < 1, originalTolerance.isFinite, originalTolerance >= 0, powerScale.isFinite, powerScale > 0,
              powerTolerance.isFinite, powerTolerance >= 0 else { throw .invalidInput }
        self.maximumCoordinates=maximumCoordinates; self.maximumPorts=maximumPorts; self.maximumRelations=maximumRelations
        self.expectedLayoutRevision=expectedLayoutRevision; self.expectedModelRevision=expectedModelRevision
        self.geometryTolerance=geometryTolerance; self.originalTolerance=originalTolerance; self.powerScale=powerScale; self.powerTolerance=powerTolerance; self.isCancelled=isCancelled
    }
}
