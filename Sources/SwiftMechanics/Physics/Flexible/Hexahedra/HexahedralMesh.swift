public struct HexahedralMesh: Sendable {
    public let identifier: UInt64
    public let revision: UInt64
    public let frame: EntityID
    public let source: SourceProvenance
    public let nodes: [FlexibleNode]
    public let cells: [HexahedronCell]
    public let materials: [FlexibleMaterial]
    public let formulation: HexahedralFormulation

    public init(identifier: UInt64, revision: UInt64, frame: EntityID, source: SourceProvenance,
                nodes: [FlexibleNode], cells: [HexahedronCell], materials: [FlexibleMaterial],
                formulation: HexahedralFormulation = .trilinearFullIntegration) throws(HexahedralError) {
        guard frame.kind == .frame else { throw .invalidIdentity }
        self.identifier = identifier
        self.revision = revision
        self.frame = frame
        self.source = source
        self.nodes = nodes
        self.cells = cells
        self.materials = materials
        self.formulation = formulation
    }
}
