public struct IslandSleepAdvanceResult: Sendable {
    public let integration: IntegrationAdvanceResult
    public let work: IslandSleepWork
    internal init(integration:IntegrationAdvanceResult,work:IslandSleepWork) { self.integration=integration;self.work=work }
}
