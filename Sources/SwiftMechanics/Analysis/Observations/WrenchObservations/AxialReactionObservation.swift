
public struct AxialReactionObservation: Sendable {
    public let header:ObservationHeader
    public let joint:EntityID
    public let effort:Double
    public let effortUnit:PhysicalDimension
    public let axisSensor:Vector3
    public let sign:WrenchObservationOptions.Sign
    public let reactionNullity:Int
    public let retainedRowIDs:[UInt64]
    public let fidelity = "identified-scalar-generalized-reaction"
}
