public struct SpatialPressureSolution: Sendable {
    public let pressure:[Double]
    public let work:NumericalWork
    public let originalResidual:Double
    public init(pressure:[Double],work:NumericalWork,originalResidual:Double) {
        self.pressure=pressure;self.work=work;self.originalResidual=originalResidual
    }
}
