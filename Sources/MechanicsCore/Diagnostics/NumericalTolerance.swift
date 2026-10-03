public struct NumericalTolerance: Equatable, Sendable {
    public let absolute: Double
    public let relative: Double

    public init(absolute: Double, relative: Double) throws(CoreError) {
        guard absolute.isFinite, relative.isFinite, absolute >= 0, relative >= 0 else {
            throw .invalidTolerance
        }
        self.absolute = absolute
        self.relative = relative
    }

    public func contains(error: Double, scale: Double) throws(CoreError) -> Bool {
        guard error.isFinite, scale.isFinite, scale >= 0 else { throw .invalidTolerance }
        let threshold = absolute + relative * scale
        guard threshold.isFinite else { throw .nonFiniteResult }
        return abs(error) <= threshold
    }
}
