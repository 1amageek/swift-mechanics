public struct HybridEventSample: Sendable {
    public let gap: Double
    public let separatingSpeed: Double
    public init(gap: Double, separatingSpeed: Double) throws(HybridError) {
        guard gap.isFinite, separatingSpeed.isFinite else { throw .nonFinite }
        self.gap=gap; self.separatingSpeed=separatingSpeed
    }
}
