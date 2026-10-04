public struct TransmissionRelation: Sendable {
    public let id: UInt64
    public let kind: TransmissionRelationKind
    public init(id: UInt64, kind: TransmissionRelationKind) { self.id=id; self.kind=kind }
}
