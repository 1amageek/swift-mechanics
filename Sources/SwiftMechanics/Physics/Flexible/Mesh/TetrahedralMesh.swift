public struct TetrahedralMesh: Sendable {
    public let frame: EntityID
    public let revision: UInt64
    public let source: SourceProvenance
    public let nodes: [FlexibleNode]
    public let cells: [TetrahedronCell]
    public let materials: [FlexibleMaterial]
    public init(frame: EntityID, revision: UInt64, source: SourceProvenance, nodes: [FlexibleNode], cells: [TetrahedronCell], materials: [FlexibleMaterial]) throws(FlexibleError) {
        guard frame.kind == .frame else { throw .invalidIdentity }
        self.frame = frame
        self.revision = revision; self.source = source; self.nodes = nodes; self.cells = cells; self.materials = materials
    }
}
