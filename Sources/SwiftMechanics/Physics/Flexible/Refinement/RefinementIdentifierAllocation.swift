public struct RefinementIdentifierAllocation: Equatable, Sendable {
    public let firstMidpointNode: UInt64, firstChildCell: UInt64
    public init(firstMidpointNode: UInt64, firstChildCell: UInt64) {
        self.firstMidpointNode = firstMidpointNode; self.firstChildCell = firstChildCell
    }
}
