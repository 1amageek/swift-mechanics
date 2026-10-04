public struct TopologyAcceptedEvent: Equatable, Sendable {
    public let id: UInt64
    public let source: ModelStamp
    public let target: ModelStamp
    public let acceptedTime: Double
    public let acceptedSequence: UInt64
    public let rule: TopologyReleaseRule
    public let observed: Double
    internal init(admission: _TopologyEventAdmission) {
        id=admission.rule.id; source=admission.source; target=admission.target; acceptedTime=admission.time
        acceptedSequence=admission.sequence; rule=admission.rule; observed=admission.observed
    }
}
