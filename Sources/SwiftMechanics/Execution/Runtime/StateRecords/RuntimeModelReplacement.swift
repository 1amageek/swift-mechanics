
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public final class RuntimeModelReplacement: Sendable {
    public let expectedSource: RuntimeCheckpoint
    public let model: CompiledMechanicalModel
    public let physical: KinematicState
    public let contributors: [RuntimeContributorState]
    public let configuration: RuntimeConfiguration
    public let checkpoints: any RuntimeCheckpointHandling

    /// The caller owns physical reconciliation; the session owns atomic admission/publication.
    public init(expectedSource: RuntimeCheckpoint, model: CompiledMechanicalModel, physical: KinematicState,
                contributors: [RuntimeContributorState], configuration: RuntimeConfiguration,
                checkpoints: any RuntimeCheckpointHandling) {
        self.expectedSource=expectedSource;self.model=model;self.physical=physical
        self.contributors=contributors;self.configuration=configuration;self.checkpoints=checkpoints
    }
}
