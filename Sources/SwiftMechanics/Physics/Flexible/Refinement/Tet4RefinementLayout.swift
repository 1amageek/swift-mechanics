public final class Tet4RefinementLayout: Sendable {
    public let source: Tet4RefinementSource
    public let edges: [RefinementEdge]
    public let faces: [RefinementFace]
    public let boundaryFaces: [RefinementFace]
    public let policy: RefinementPolicy, numericalWork: NumericalWork
    internal init(source: Tet4RefinementSource, edges: [RefinementEdge], faces: [RefinementFace],
                  boundary: [RefinementFace], policy: RefinementPolicy, work: NumericalWork) {
        self.source = source; self.edges = edges; self.faces = faces; self.boundaryFaces = boundary
        self.policy = policy; self.numericalWork = work
    }
}
