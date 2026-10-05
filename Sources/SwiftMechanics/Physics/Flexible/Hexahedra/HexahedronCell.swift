public struct HexahedronCell: Equatable, Sendable {
    public let identifier: UInt64
    /// Natural order: ---,+--,++-,-+-,--+,+-+,+++,-++.
    public let nodes: [Int]
    public let material: EntityID
    public let source: SourceProvenance

    public init(identifier: UInt64, nodes: [Int], material: EntityID, source: SourceProvenance) throws(HexahedralError) {
        guard nodes.count == 8 else { throw .invalidConnectivity }
        guard material.kind == .material else { throw .invalidIdentity }
        self.identifier = identifier
        self.nodes = nodes
        self.material = material
        self.source = source
    }
}
