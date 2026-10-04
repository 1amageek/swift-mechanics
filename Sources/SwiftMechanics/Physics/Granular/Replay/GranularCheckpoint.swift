public struct GranularCheckpoint: Sendable {
    public let state: GranularState
    internal init(state: GranularState) { self.state=state }
}
