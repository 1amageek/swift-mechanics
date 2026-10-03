public struct PhysicalResidual: Equatable, Sendable {
    public let equation: DynamicsEquationKind
    /// Dimensionless after caller coordinate/energy scaling.
    public let infinityNorm: Double
    public let referenceScale: Double
    public let threshold: Double
    public var isAccepted: Bool { infinityNorm <= threshold }
    internal init(equation: DynamicsEquationKind, infinityNorm: Double, referenceScale: Double, threshold: Double) {
        self.equation = equation; self.infinityNorm = infinityNorm; self.referenceScale = referenceScale; self.threshold = threshold
    }
}
