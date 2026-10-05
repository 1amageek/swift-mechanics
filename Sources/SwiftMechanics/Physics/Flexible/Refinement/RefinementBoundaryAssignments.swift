/// Explicit group decisions aligned with the issued layout. Nil is a deliberate absent assignment.
public struct RefinementBoundaryAssignments: Sendable {
    public let layout: Tet4RefinementLayout
    public let owner: String
    public let midpointGroups: [UInt64?]
    public let originalFaceGroups: [UInt64?]
    public init(layout: Tet4RefinementLayout, owner: String, midpointGroups: [UInt64?],
                originalFaceGroups: [UInt64?]) throws(RefinementError) {
        guard !owner.isEmpty, midpointGroups.count == layout.edges.count,
              originalFaceGroups.count == layout.boundaryFaces.count else { throw .invalidAssignment }
        self.layout = layout; self.owner = owner; self.midpointGroups = midpointGroups
        self.originalFaceGroups = originalFaceGroups
    }
}
