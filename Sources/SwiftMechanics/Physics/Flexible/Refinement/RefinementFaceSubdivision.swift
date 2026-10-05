public struct RefinementFaceSubdivision: Sendable {
    public let original: RefinementFace
    public let children: [RefinementFace]
    public let boundaryGroup: UInt64?
    public let boundaryAssignmentOwner: String
    public let originalDoubleArea: Double, refinedDoubleArea: Double, areaVectorResidual: Double
    internal init(original: RefinementFace, children: [RefinementFace], group: UInt64?, owner: String,
                  originalArea: Double, refinedArea: Double, areaResidual: Double) {
        self.original = original; self.children = children; self.boundaryGroup = group
        self.boundaryAssignmentOwner = owner
        self.originalDoubleArea = originalArea; self.refinedDoubleArea = refinedArea; self.areaVectorResidual = areaResidual
    }
}
