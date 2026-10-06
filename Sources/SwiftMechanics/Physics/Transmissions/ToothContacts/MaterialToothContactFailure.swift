public struct MaterialToothContactFailure: Error, Sendable {
    public let cause: ToothContactError
    public let accepted: MaterialToothContactState
    public let work: ToothContactWork
    public let completedSteps: Int
    internal init(cause: ToothContactError, accepted: MaterialToothContactState, work: ToothContactWork, completedSteps: Int) {
        self.cause=cause; self.accepted=accepted; self.work=work; self.completedSteps=completedSteps
    }
}
