@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol MechanismSleepContinuing: RuntimeContributorHandling {
    var schema: RuntimeContributorSchema { get }
    func initialRecord(physical:KinematicState,acceptedSequence:UInt64) throws(RuntimeFailure) -> RuntimeContributorState
    func history(_ record:RuntimeContributorState) throws(RuntimeFailure) -> MechanismSleepHistory
    func step(_ session:any RuntimeSessionOperating) throws(MechanismSleepFailure) -> IntegrationAdvanceResult
    func command(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,drive:[Double],generation:UInt64,
                 work:inout NumericalWork) throws(RuntimeFailure) -> RuntimeTrialOutcome
    func impact(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,impulse:MechanismSleepImpulse,
                work:inout NumericalWork) throws(RuntimeFailure) -> RuntimeTrialOutcome
}
