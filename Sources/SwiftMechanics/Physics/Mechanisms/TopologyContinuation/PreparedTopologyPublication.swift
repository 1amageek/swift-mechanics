@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public final class PreparedTopologyPublication: Sendable {
    public let source:RuntimeAcceptedState
    public let sourceConfiguration:RuntimeConfiguration
    public let transition:ReconciledSubtreeRelease
    public let configuration:RuntimeConfiguration
    public let contributors:[RuntimeContributorState]
    public let handler:TopologyCheckpointHandler
    public let actuatorMigrations:[ScalarActuatorTopologyMigration]
    internal init(admission:_TopologyPublicationAdmission) {
        source=admission.source;sourceConfiguration=admission.sourceConfiguration;transition=admission.transition
        configuration=admission.configuration;contributors=admission.contributors;handler=admission.handler;actuatorMigrations=admission.actuators
    }
}
