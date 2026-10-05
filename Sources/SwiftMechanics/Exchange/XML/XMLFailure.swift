public struct XMLFailure: Error, Equatable, Sendable {
    public let reason: XMLFailureReason
    public let location: XMLLocation
    public init(_ reason: XMLFailureReason, at location: XMLLocation) {
        self.reason = reason; self.location = location
    }
}
