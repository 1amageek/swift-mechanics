public struct TopologyReleaseRule: Equatable, Sendable {
    public let id: UInt64
    public let joint: EntityID
    public let connector: EntityID
    public let parentAnchor: EntityID
    public let childAnchor: EntityID
    public let subtreeRoot: EntityID
    public let metric: TopologyReleaseMetric
    public let threshold: Double
    public init(id:UInt64,joint:EntityID,connector:EntityID,parentAnchor:EntityID,childAnchor:EntityID,
                subtreeRoot:EntityID,metric:TopologyReleaseMetric,threshold:Double=0) throws(TopologyReleaseFailure) {
        guard joint.kind == .joint, connector.kind == .joint, joint != connector, parentAnchor.kind == .frame,
              childAnchor.kind == .frame, parentAnchor != childAnchor, subtreeRoot.kind == .body,
              threshold.isFinite, threshold >= 0, metric != .explicitRelease || threshold == 0 else { throw .invalidInput }
        self.id=id; self.joint=joint; self.connector=connector; self.parentAnchor=parentAnchor; self.childAnchor=childAnchor
        self.subtreeRoot=subtreeRoot; self.metric=metric; self.threshold=threshold
    }
}
