import MechanicsModel
public struct TetrahedronCell: Equatable, Sendable {
    public let identifier: UInt64
    public let nodes: [Int]
    public let material: EntityID
    public let source: SourceProvenance
    public let parentIdentifier: UInt64?
    public init(identifier: UInt64, nodes: [Int], material: EntityID, source: SourceProvenance, parentIdentifier: UInt64? = nil) throws(FlexibleError) {
        guard nodes.count == 4 else { throw .invalidConnectivity }
        guard material.kind == .material else { throw .invalidIdentity }
        self.identifier = identifier; self.nodes = nodes; self.material = material; self.source = source; self.parentIdentifier = parentIdentifier
    }
}
