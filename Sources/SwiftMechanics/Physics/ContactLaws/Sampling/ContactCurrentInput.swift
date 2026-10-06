public struct ContactCurrentInput: Sendable {
    public let identity: ContactIdentity
    public let basis: ContactBasis
    public let separation: Double
    public let relativeVelocity: Vector3
    public let relativeAngularVelocity: Vector3
    public let timeSeconds: Double

    public init(identity: ContactIdentity, basis: ContactBasis, separation: Double,
                relativeVelocity: Vector3, relativeAngularVelocity: Vector3,
                timeSeconds: Double) throws(ContactCurrentError) {
        guard identity.frame == basis.frame else { throw .law(.frameMismatch) }
        guard separation.isFinite, timeSeconds.isFinite, timeSeconds >= 0 else { throw .law(.invalidInput) }
        self.identity=identity; self.basis=basis; self.separation=separation
        self.relativeVelocity=relativeVelocity; self.relativeAngularVelocity=relativeAngularVelocity
        self.timeSeconds=timeSeconds
    }
}
