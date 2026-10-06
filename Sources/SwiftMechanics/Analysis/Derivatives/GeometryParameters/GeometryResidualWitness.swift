public struct GeometryResidualWitness: Equatable, Sendable {
    /// Maximum residual divided by its caller-declared component threshold; success requires <= 1.
    public let maximumNormalizedResidual: Double
    public let checkedComponents: Int
    internal init(maximumNormalizedResidual: Double, checkedComponents: Int) {
        self.maximumNormalizedResidual = maximumNormalizedResidual; self.checkedComponents = checkedComponents
    }
}
