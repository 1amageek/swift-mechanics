public struct IslandSleepAdmissionFailure: Error, Sendable {
    public let cause:RuntimeFailure
    public let checkpointAdmission:IslandSleepWork?
    internal init(cause:RuntimeFailure,work:IslandSleepWork?) { self.cause=cause;checkpointAdmission=work }
}
