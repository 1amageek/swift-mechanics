public struct DiscreteCable: Sendable {
    public let frame: EntityID
    public let revision: UInt64
    public let source: SourceProvenance
    public let nodes: [FlexibleNode]
    public let material: CableMaterial
    public let formulation: CableFormulation

    public init(frame: EntityID, revision: UInt64, source: SourceProvenance, nodes: [FlexibleNode],
                material: CableMaterial, formulation: CableFormulation) throws(CableError) {
        guard frame.kind == .frame, nodes.count >= 2 else { throw .invalidInput }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Particle cable admission is the production entry point;
        // torsion has no director DOF. A director-based energy/force/tangent and behavioral evidence
        // are required before torsionalRod may produce an admitted successful model.
        guard formulation != .torsionalRod else { throw .unsupportedTwist }
        self.frame = frame; self.revision = revision; self.source = source; self.nodes = nodes
        self.material = material; self.formulation = formulation
    }
}
