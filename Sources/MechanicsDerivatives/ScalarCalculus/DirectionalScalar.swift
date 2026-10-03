public struct DirectionalScalar: Equatable, Sendable {
    public let value: Double
    public let direction: Double
    public init(value: Double, direction: Double) throws(DerivativeError) {
        guard value.isFinite, direction.isFinite else { throw .nonFiniteResult }
        self.value=value; self.direction=direction
    }
}
