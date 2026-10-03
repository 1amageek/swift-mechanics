public struct ColliderFilter: Equatable, Sendable {
    public let enabled: Bool
    public let layerBits: UInt64
    public let maskBits: UInt64
    public let isTrigger: Bool

    public init(enabled: Bool, layerBits: UInt64, maskBits: UInt64, isTrigger: Bool) {
        self.enabled = enabled; self.layerBits = layerBits
        self.maskBits = maskBits; self.isTrigger = isTrigger
    }
}
