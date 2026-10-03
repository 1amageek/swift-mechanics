public struct QuadraticConstraintSystem: Sendable {
    public let layout: ConstraintCoordinateLayout
    public let rows: [QuadraticConstraint]
    public let minimumPosition: [Double]
    public let maximumPosition: [Double]
    public let minimumTime: Double
    public let maximumTime: Double
    public init(layout: ConstraintCoordinateLayout, rows: [QuadraticConstraint], minimumPosition: [Double], maximumPosition: [Double], minimumTime: Double, maximumTime: Double) throws(ConstraintError) {
        guard !rows.isEmpty, minimumPosition.count == layout.scales.count, maximumPosition.count == layout.scales.count,
              minimumTime.isFinite, maximumTime.isFinite, minimumTime <= maximumTime else { throw .invalidDimensions }
        self.layout=layout; self.rows=rows; self.minimumPosition=minimumPosition; self.maximumPosition=maximumPosition
        self.minimumTime=minimumTime; self.maximumTime=maximumTime
    }
}
