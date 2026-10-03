public struct ResidualEvidence<Scalar: NumericalScalar>: Sendable {
    public let infinityNorm: Scalar
    public let referenceScale: Scalar
    public let threshold: Scalar
    public var isAccepted: Bool { infinityNorm <= threshold }
    public init(infinityNorm: Scalar, referenceScale: Scalar, threshold: Scalar) throws(NumericalError) {
        guard infinityNorm.isFinite, referenceScale.isFinite, threshold.isFinite,
              infinityNorm >= 0, referenceScale >= 0, threshold >= 0 else { throw .nonFiniteResult }
        self.infinityNorm = infinityNorm; self.referenceScale = referenceScale; self.threshold = threshold
    }
    public static func measure(product: [Scalar], rightHandSide: [Scalar], tolerance: LinearTolerance<Scalar>) throws(NumericalError) -> Self {
        guard product.count == rightHandSide.count, !product.isEmpty else { throw .invalidDimensions }
        var residual: Scalar = 0, scale: Scalar = 0
        for i in product.indices {
            guard product[i].isFinite, rightHandSide[i].isFinite else { throw .nonFiniteResult }
            let difference = product[i] - rightHandSide[i]
            guard difference.isFinite else { throw .nonFiniteResult }
            residual = max(residual, abs(difference)); scale = max(scale, max(abs(product[i]), abs(rightHandSide[i])))
        }
        return try Self(infinityNorm: residual, referenceScale: scale, threshold: tolerance.threshold(scale: scale))
    }
    public func requireAccepted() throws(NumericalError) {
        guard isAccepted else { throw .residualRejected(value: Double(infinityNorm), threshold: Double(threshold)) }
    }
}
