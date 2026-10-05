public struct GeometryParameterProduct: Sendable {
    public let source: GeometryParameterSource
    public let parameterDirection: [Double]
    public let snapshot: KinematicSnapshot
    public let bodies: [GeometryBodyProduct]
    /// World, body, and joint-anchor frames, in the original snapshot's frame order.
    public let frames: [GeometryFrameProduct]
    /// Row-major body/velocity columns in world frame at each actual body origin.
    public let geometricColumns: [SpatialMotion]
    public let coordinateRate: [Double]
    public let normalizedAxes: [GeometryAxisWitness]
    public let originalPrimal: GeometryResidualWitness
    public let originalMotionResidual: GeometryResidualWitness
    public let supplierWork: DerivativeSupplierWork
    public let numericalWork: NumericalWork
    public let stateHeldFixed = true
    internal init(source: GeometryParameterSource, parameterDirection: [Double], snapshot: KinematicSnapshot,
                  bodies: [GeometryBodyProduct], frames: [GeometryFrameProduct], geometricColumns: [SpatialMotion], coordinateRate: [Double],
                  normalizedAxes: [GeometryAxisWitness], originalPrimal: GeometryResidualWitness,
                  originalMotionResidual: GeometryResidualWitness, supplierWork: DerivativeSupplierWork, numericalWork: NumericalWork) {
        self.source = source; self.parameterDirection = parameterDirection; self.snapshot = snapshot; self.bodies = bodies
        self.frames = frames; self.geometricColumns = geometricColumns; self.coordinateRate = coordinateRate; self.normalizedAxes = normalizedAxes
        self.originalPrimal = originalPrimal; self.originalMotionResidual = originalMotionResidual
        self.supplierWork = supplierWork; self.numericalWork = numericalWork
    }
}
