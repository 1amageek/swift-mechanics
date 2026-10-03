import MechanicsRuntime
import MechanicsIntegration

public struct HybridTrajectoryResult: Sendable {
    public let checkpoint: RuntimeCheckpoint
    public let work: IntegrationWorkReport
    public init(checkpoint: RuntimeCheckpoint, work: IntegrationWorkReport) { self.checkpoint=checkpoint; self.work=work }
}
