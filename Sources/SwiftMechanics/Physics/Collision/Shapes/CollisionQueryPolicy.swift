public struct CollisionQueryPolicy: Sendable {
    public let lengthTolerance: Double
    public let normalTolerance: Double
    public let maximumApproximationError: Double

    public init(absoluteLengthTolerance: Double, relativeLengthTolerance: Double,
                referenceLength: Double, maximumApproximationError: Double) throws(CollisionError) {
        guard absoluteLengthTolerance.isFinite, absoluteLengthTolerance >= 0,
              relativeLengthTolerance.isFinite, relativeLengthTolerance >= 0,
              referenceLength.isFinite, referenceLength > 0,
              maximumApproximationError.isFinite, maximumApproximationError >= 0 else { throw .invalidPolicy }
        lengthTolerance = try collisionFinite(absoluteLengthTolerance + relativeLengthTolerance * referenceLength)
        normalTolerance = try collisionFinite(relativeLengthTolerance + absoluteLengthTolerance / referenceLength)
        self.maximumApproximationError = maximumApproximationError
    }

    public func validate(_ proxy: CollisionProxy) throws(CollisionError) {
        let error = proxy.geometry.approximationError
        guard error <= maximumApproximationError else { throw .approximationExceeded(value: error, maximum: maximumApproximationError) }
    }
}
