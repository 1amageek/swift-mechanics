@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol IslandEndpointContributing: RuntimeContributorHandling {
    func recordEndpoint(source:RuntimeCheckpoint,physical:KinematicState,acceptedSequence:UInt64,work:inout NumericalWork) throws(RuntimeFailure) -> RuntimeContributorState
    func validateAssociation(record:RuntimeContributorState,physical:KinematicState,acceptedSequence:UInt64,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence
}
