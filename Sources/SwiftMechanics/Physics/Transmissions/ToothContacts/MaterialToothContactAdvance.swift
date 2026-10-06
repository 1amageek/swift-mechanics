public struct MaterialToothContactAdvance: Sendable {
    public let accepted: MaterialToothContactState
    public let completedSteps: Int
    public let work: ToothContactWork
    internal init(accepted: MaterialToothContactState, completedSteps: Int, work: ToothContactWork) {
        self.accepted=accepted; self.completedSteps=completedSteps; self.work=work
    }
}
