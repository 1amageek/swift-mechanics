public struct HybridEventBracket: Sendable {
    public let eventID: UInt64
    public let lowerTime: Double
    public let upperTime: Double
    public init(eventID: UInt64, lowerTime: Double, upperTime: Double) throws(HybridError) {
        guard lowerTime.isFinite, upperTime.isFinite, lowerTime < upperTime else { throw .invalidInput }
        self.eventID=eventID; self.lowerTime=lowerTime; self.upperTime=upperTime
    }
}
