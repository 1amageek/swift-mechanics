@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol IslandMechanismSleepContinuing: RuntimeContributorHandling {
    var model:CompiledMechanicalModel { get }
    var program:StationaryIslandProgram { get }
    var descriptor:ODEDescriptor { get }
    var continuation:IntegrationContinuationProvider { get }
    var schema:RuntimeContributorSchema { get }
    func initialRecord(physical:KinematicState,acceptedSequence:UInt64) throws(RuntimeFailure) -> RuntimeContributorState
    func initialIntegrationRecord(physical:KinematicState,acceptedSequence:UInt64) throws(RuntimeFailure) -> RuntimeContributorState
    func history(_ record:RuntimeContributorState) throws(RuntimeFailure) -> IslandSleepHistory
    func step(_ session:any RuntimeSessionOperating,work:inout IslandSleepWork) throws(IslandSleepFailure) -> IslandSleepAdvanceResult
    func query(from source:RuntimeAcceptedState,configuration:RuntimeConfiguration,to time:Double,work:inout IslandSleepWork,cancellation:RuntimeCancellationSource?) throws(IslandSleepFailure) -> IslandSleepTrajectoryEndpoint
    func prepareSmoothEndpoint(source:RuntimeAcceptedState,endpoint:IslandSleepTrajectoryEndpoint,work:inout IslandSleepWork) throws(IslandSleepFailure) -> PreparedIslandSmoothEndpoint
    func prepareImpactWake(source:RuntimeAcceptedState,endpoint:IslandSleepTrajectoryEndpoint,impact:ConstrainedNormalImpulseResult,work:inout IslandSleepWork) throws(IslandSleepFailure) -> PreparedIslandImpactWake
}
