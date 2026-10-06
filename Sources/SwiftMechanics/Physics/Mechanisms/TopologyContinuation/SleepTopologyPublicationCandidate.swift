@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class SleepTopologyPublicationCandidate: Sendable {
    let source:RuntimeAcceptedState
    let sourceConfiguration:RuntimeConfiguration
    let retirement:PreparedSleepTopologyRetirement
    let transition:NonlinearReconciledSubtreeRelease
    let configuration:RuntimeConfiguration
    let wake:SleepTopologyWakeContributor
    let continuation:IntegrationContinuationProvider
    let handler:TopologyCheckpointHandler
    let checkpoints:SleepTopologyCheckpointHandler
    let checkpoint:RuntimeCheckpoint
    init(source:RuntimeAcceptedState,sourceConfiguration:RuntimeConfiguration,retirement:PreparedSleepTopologyRetirement,
         transition:NonlinearReconciledSubtreeRelease,configuration:RuntimeConfiguration,wake:SleepTopologyWakeContributor,
         continuation:IntegrationContinuationProvider,handler:TopologyCheckpointHandler,checkpoints:SleepTopologyCheckpointHandler,checkpoint:RuntimeCheckpoint) {
        self.source=source;self.sourceConfiguration=sourceConfiguration;self.retirement=retirement;self.transition=transition
        self.configuration=configuration;self.wake=wake;self.continuation=continuation;self.handler=handler;self.checkpoints=checkpoints;self.checkpoint=checkpoint
    }
}
