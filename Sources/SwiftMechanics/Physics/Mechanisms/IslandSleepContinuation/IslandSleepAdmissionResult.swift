public struct IslandSleepAdmissionResult: Sendable {
    public let accepted:RuntimeAcceptedState
    public let checkpointAdmission:IslandSleepWork
    internal init(accepted:RuntimeAcceptedState,work:IslandSleepWork) { self.accepted=accepted;checkpointAdmission=work }
}
