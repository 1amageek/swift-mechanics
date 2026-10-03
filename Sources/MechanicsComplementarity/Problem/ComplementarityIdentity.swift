/// Revisions describe coordinate meaning, ordered layout/basis and law semantics.
public struct ComplementarityIdentity: Equatable, Sendable {
    public let revision: UInt64
    public let coordinateIDs: [UInt64]
    public let frameLayoutRevision: UInt64
    public let lawRevision: UInt64

    public init(revision: UInt64, coordinateIDs: [UInt64], frameLayoutRevision: UInt64, lawRevision: UInt64) {
        self.revision = revision; self.coordinateIDs = coordinateIDs
        self.frameLayoutRevision = frameLayoutRevision; self.lawRevision = lawRevision
    }
}
