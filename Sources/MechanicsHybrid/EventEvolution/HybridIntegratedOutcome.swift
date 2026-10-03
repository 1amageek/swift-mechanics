import MechanicsIntegration

internal final class HybridIntegratedOutcome: Sendable {
    let result: IntegrationAdvanceResult
    init(_ result: IntegrationAdvanceResult) { self.result=result }
}
