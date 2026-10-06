public struct ToothContactFailure: Error, Sendable {
    public let cause: ToothContactError
    public let accepted: ToothContactState
    public let work: ToothContactWork
    public let completedSteps: Int
}
