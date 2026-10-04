@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol LoadedMechanismSleepContinuing:RuntimeContributorHandling {
    var schema:RuntimeContributorSchema { get }
    func initialRecord(physical:KinematicState,acceptedSequence:UInt64) throws(RuntimeFailure) -> RuntimeContributorState
    func initialIntegrationRecord(physical:KinematicState) throws(RuntimeFailure) -> RuntimeContributorState
    func history(_ record:RuntimeContributorState) throws(RuntimeFailure) -> LoadedMechanismSleepHistory
    func stepWithLoads(_ session:any RuntimeSessionOperating,loadBudget:LoadBudget,maximumLoadInvocations:Int) throws(LoadedMechanismSleepFailure) -> LoadedMechanismAdvanceResult
    func selectLoad(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,selection:StationaryLoadSelection,loadBudget:LoadBudget,maximumLoadInvocations:Int,work:inout NumericalWork) throws(LoadedMechanismSleepFailure) -> LoadedMechanismWakeResult
    func commandWithLoads(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,drive:[Double],generation:UInt64,loadBudget:LoadBudget,maximumLoadInvocations:Int,work:inout NumericalWork) throws(LoadedMechanismSleepFailure) -> LoadedMechanismWakeResult
    func impactWithLoads(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,impulse:MechanismSleepImpulse,loadBudget:LoadBudget,maximumLoadInvocations:Int,work:inout NumericalWork) throws(LoadedMechanismSleepFailure) -> LoadedMechanismWakeResult
}
