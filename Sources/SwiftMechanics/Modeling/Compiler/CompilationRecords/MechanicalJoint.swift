
public struct MechanicalJoint: Equatable, Sendable {
    public let record: JointRecord
    public let authority: CoordinateAuthority

    public init(record: JointRecord, authority: CoordinateAuthority) {
        self.record = record; self.authority = authority
    }
}
