
public struct RuntimeCheckpoint: Equatable, Sendable {
    public let model: ModelStamp
    public let continuation: RuntimeContinuationIdentity
    public let physical: KinematicState
    public let contributors: [RuntimeContributorState]
    public let random: RuntimeRandomState
    public let acceptedSteps: UInt64
    public init(model: ModelStamp, continuation: RuntimeContinuationIdentity, physical: KinematicState,
                contributors: [RuntimeContributorState], random: RuntimeRandomState, acceptedSteps: UInt64) throws(RuntimeFailure) {
        guard physical.revision == model.revision else { throw RuntimeFailure(.incompatibleModel, message: "Physical and checkpoint revisions differ.") }
        self.model = model; self.continuation = continuation; self.physical = physical
        self.contributors = contributors; self.random = random; self.acceptedSteps = acceptedSteps
    }
}
