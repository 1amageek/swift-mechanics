/// Tolerance and characteristic SI scale for one dimensional original equation.
public struct ParticleFlowResidualScale: Equatable, Sendable {
    public let tolerance: NumericalTolerance
    public let scale: Double
    public init(tolerance: NumericalTolerance, scale: Double) throws(ParticleFlowError) {
        guard scale.isFinite, scale > 0 else { throw .invalidPolicy }
        self.tolerance = tolerance; self.scale = scale
    }
}
