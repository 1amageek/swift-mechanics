public struct TopologyEventCatalog: Equatable, Sendable {
    public let initialModel: ModelStamp
    public let initialTime: Double
    public let initialSequence: UInt64
    public let rules: [TopologyReleaseRule]
    public init(initialModel:ModelStamp,initialTime:Double,initialSequence:UInt64,rules:[TopologyReleaseRule],policy:TopologyContinuationPolicy) throws(TopologyReleaseFailure) {
        guard !initialModel.identity.isEmpty,initialTime.isFinite,!rules.isEmpty,rules.count <= policy.maximumEvents else { throw .invalidInput }
        let (pairs,pairOverflow)=rules.count.multipliedReportingOverflow(by:rules.count)
        let (bound,workOverflow)=pairs.multipliedReportingOverflow(by:128)
        guard !pairOverflow,!workOverflow,bound <= policy.maximumWork else { throw .capacityExceeded }
        var metadata=initialModel.identity.utf8.count
        guard metadata <= policy.maximumMetadataBytes else { throw .capacityExceeded }
        for (index,rule) in rules.enumerated() {
            guard index == 0 || rules[index-1].id < rule.id else { throw .invalidInput }
            for text in [rule.joint.key,rule.connector.key,rule.parentAnchor.key,rule.childAnchor.key,rule.subtreeRoot.key] {
                let (next,overflow)=metadata.addingReportingOverflow(text.utf8.count)
                guard !overflow,next <= policy.maximumMetadataBytes else { throw .capacityExceeded };metadata=next
            }
            for previous in rules[..<index] {
                guard previous.joint != rule.joint, previous.connector != rule.connector,
                      previous.parentAnchor != rule.parentAnchor,previous.childAnchor != rule.childAnchor,
                      previous.parentAnchor != rule.childAnchor,previous.childAnchor != rule.parentAnchor else { throw .invalidInput }
            }
        }
        self.initialModel=initialModel; self.initialTime=initialTime; self.initialSequence=initialSequence; self.rules=rules
    }
}
