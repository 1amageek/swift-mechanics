public enum ExplicitIntegrationMethod: UInt8, Equatable, Sendable {
    case classicalRK4 = 0, heunEuler = 1
    public var order: Int { self == .classicalRK4 ? 4 : 2 }
    public var embeddedOrder: Int? { self == .heunEuler ? 1 : nil }
}
