/// Complete catalog and original physical target prepared for one atomic accepted replacement.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public final class PreparedSleepTopologyPublication: Sendable {
    public let source:RuntimeAcceptedState
    public let sourceConfiguration:RuntimeConfiguration
    public let retirement:PreparedSleepTopologyRetirement
    public let transition:NonlinearReconciledSubtreeRelease
    public let configuration:RuntimeConfiguration
    public let contributors:[RuntimeContributorState]
    public let wake:SleepTopologyWakeContributor
    public let continuation:IntegrationContinuationProvider
    public let handler:TopologyCheckpointHandler
    public let checkpoints:any RuntimeCheckpointHandling
    internal init(admission:_SleepTopologyPublicationAdmission) {
        let candidate=admission.candidate
        source=candidate.source;sourceConfiguration=candidate.sourceConfiguration;retirement=candidate.retirement
        transition=candidate.transition;configuration=candidate.configuration;contributors=candidate.checkpoint.contributors
        wake=candidate.wake;continuation=candidate.continuation;handler=candidate.handler;checkpoints=candidate.checkpoints
    }
}
