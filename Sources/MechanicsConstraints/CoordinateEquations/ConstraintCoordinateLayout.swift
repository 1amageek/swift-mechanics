import MechanicsCore

/// SI coordinates are converted to dimensionless x=q/S and u=v*T/S.
public struct ConstraintCoordinateLayout: Sendable {
    public let coordinateIDs: [UInt64]
    public let dimensions: [PhysicalDimension]
    public let scales: [Double]
    public let timeScale: Double
    public let revision: UInt64
    public init(coordinateIDs: [UInt64], dimensions: [PhysicalDimension], scales: [Double], timeScale: Double, revision: UInt64) throws(ConstraintError) {
        guard !coordinateIDs.isEmpty, dimensions.count == coordinateIDs.count, scales.count == coordinateIDs.count,
              timeScale.isFinite, timeScale > 0 else { throw .invalidDimensions }
        self.coordinateIDs=coordinateIDs; self.dimensions=dimensions; self.scales=scales; self.timeScale=timeScale; self.revision=revision
    }
}
