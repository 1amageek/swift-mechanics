public struct WrenchObservationOptions: Sendable {
    public enum Sign: Equatable, Sendable { case intoBody, outOfBody }
    public enum GravityCompensation: Equatable, Sendable { case none, subtractBodyGravity }
    public let sign:Sign
    public let gravityCompensation:GravityCompensation
    public init(sign:Sign = .intoBody,gravityCompensation:GravityCompensation = .none) {
        self.sign=sign;self.gravityCompensation=gravityCompensation
    }
}
