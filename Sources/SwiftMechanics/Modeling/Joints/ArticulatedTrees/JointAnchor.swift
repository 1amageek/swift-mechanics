
public struct JointAnchor: Equatable, Sendable {
    public let frame: EntityID
    public let placement: AnchorPlacement

    public init(frame: EntityID, placement: AnchorPlacement) throws(JointError) {
        guard frame.kind == .frame else { throw .identityKindMismatch }
        self.frame = frame
        self.placement = placement
    }
}
