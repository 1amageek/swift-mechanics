public struct ContactDirection: Sendable {
    public let separation: Double
    public let relativeVelocity: Vector3
    public init(separation: Double, relativeVelocity: Vector3) throws(ContactDerivativeError) {
        guard separation.isFinite else { throw .invalidInput }
        self.separation=separation; self.relativeVelocity=relativeVelocity
    }
}
