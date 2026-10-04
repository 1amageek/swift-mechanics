@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public protocol TopologyTransitionPreparing: Sendable {
    func prepare(source:RuntimeAcceptedState,sourceConfiguration:RuntimeConfiguration,transition:ReconciledSubtreeRelease,
                 history:TopologyHistoryContributor,observation:TopologyReleaseObservation,ruleID:UInt64,
                 dispositions:[TopologyContributorDisposition],targetConfiguration:RuntimeConfiguration,
                 work:inout NumericalWork,actuationWork:inout ActuationWork) throws(TopologyReleaseFailure) -> PreparedTopologyPublication
    func publish(_ prepared:PreparedTopologyPublication,session:any RuntimeModelReplacing) throws(TopologyReleaseFailure) -> RuntimeAcceptedState
}
