public struct LinearTolerance<Scalar: NumericalScalar>: Sendable {
    public let absoluteResidual: Scalar
    public let relativeResidual: Scalar
    public let pivotThreshold: Scalar
    public init(absoluteResidual: Scalar, relativeResidual: Scalar, pivotThreshold: Scalar) throws(NumericalError) {
        guard absoluteResidual.isFinite, relativeResidual.isFinite, pivotThreshold.isFinite,
              absoluteResidual >= 0, relativeResidual >= 0, pivotThreshold >= 0 else { throw .invalidPolicy }
        self.absoluteResidual = absoluteResidual; self.relativeResidual = relativeResidual; self.pivotThreshold = pivotThreshold
    }
    public func threshold(scale: Scalar) throws(NumericalError) -> Scalar {
        let value = absoluteResidual + relativeResidual * scale
        guard scale.isFinite, scale >= 0, value.isFinite else { throw .nonFiniteResult }
        return value
    }
}
