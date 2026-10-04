public struct VelocityConstraintSample: Sendable {
    public let layout: ConstraintCoordinateLayout
    public let rowIDs: [UInt64]
    public let rows: [Double]
    public let drift: [Double]
    public let accelerationBias: [Double]
    public let isIntegrable: Bool
    public init(layout: ConstraintCoordinateLayout, rowIDs: [UInt64], rows: [Double], drift: [Double], accelerationBias: [Double], isIntegrable: Bool) {
        self.layout=layout; self.rowIDs=rowIDs; self.rows=rows; self.drift=drift; self.accelerationBias=accelerationBias; self.isIntegrable=isIntegrable
    }
    public init(layout: ConstraintCoordinateLayout, holonomic: ConstraintEvaluation) {
        self.init(layout:layout,rowIDs:holonomic.rowIDs,rows:holonomic.jacobian,drift:holonomic.timeDerivative,accelerationBias:holonomic.accelerationBias,isIntegrable:true)
    }
}
