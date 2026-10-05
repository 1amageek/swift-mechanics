public struct RetimingQuery: Sendable {
    public let sourceID: String
    public let pathID: String
    public let sourceRevision: UInt64
    public let time: Double
    public init(sourceID: String, pathID: String, sourceRevision: UInt64, time: Double) {
        self.sourceID = sourceID; self.pathID = pathID; self.sourceRevision = sourceRevision; self.time = time
    }
}
