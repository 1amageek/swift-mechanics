public struct HexahedralNodalState: Sendable {
    public let revision: UInt64
    public let source: SourceProvenance
    public let meshIdentifier: UInt64
    public let meshRevision: UInt64
    public let frame: EntityID
    public let meshSource: SourceProvenance
    public let nodeIdentifiers: [UInt64]
    /// Current positions in m, in the mesh frame and node order.
    public let positions: [Vector3]
    /// Current velocities in m/s, in the same frame and node order.
    public let velocities: [Vector3]

    public init(revision: UInt64, source: SourceProvenance,
                meshIdentifier: UInt64, meshRevision: UInt64, frame: EntityID, meshSource: SourceProvenance,
                nodeIdentifiers: [UInt64], positions: [Vector3], velocities: [Vector3]) {
        self.revision = revision
        self.source = source
        self.meshIdentifier = meshIdentifier
        self.meshRevision = meshRevision
        self.frame = frame
        self.meshSource = meshSource
        self.nodeIdentifiers = nodeIdentifiers
        self.positions = positions
        self.velocities = velocities
    }
}
