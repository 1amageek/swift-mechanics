@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public protocol SleepTopologyTransitionPreparing: Sendable {
    func prepare(source:RuntimeAcceptedState,sourceConfiguration:RuntimeConfiguration,retirement:PreparedSleepTopologyRetirement,
        transition:NonlinearReconciledSubtreeRelease,history:TopologyHistoryContributor,observation:TopologyReleaseObservation,
        ruleID:UInt64,dispositions:[SleepTopologyContributorDisposition],targetConfiguration:RuntimeConfiguration,
        equations:NonlinearMechanismEquation,continuation:IntegrationContinuationProvider,validationBudget:NumericalBudget,
        cancellation:RuntimeCancellationSource?,work:inout NumericalWork) throws(TopologyReleaseFailure) -> PreparedSleepTopologyPublication
    func publish(_ prepared:PreparedSleepTopologyPublication,session:any RuntimeModelReplacing) throws(TopologyReleaseFailure) -> RuntimeAcceptedState
}
