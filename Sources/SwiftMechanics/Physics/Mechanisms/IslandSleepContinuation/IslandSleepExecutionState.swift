internal struct IslandSleepExecutionState: Sendable {
    var work:IslandSleepWork
    var busy=false
    var failure:IslandSleepFailureReason?
    init(work:IslandSleepWork) { self.work=work }
}
