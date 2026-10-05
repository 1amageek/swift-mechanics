public struct ConcentratedRefinementLoads: Sendable {
    public let source: Tet4RefinementSource
    /// Dense covectors at original nodes in exact original node order and source frame, in newtons.
    public let forces: [Vector3]
    public init(source: Tet4RefinementSource, forces: [Vector3]) throws(RefinementError) {
        guard forces.count == source.mesh.mesh.nodes.count else { throw .staleLayout }
        self.source = source; self.forces = forces
    }
}
