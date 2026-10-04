public struct GeometricPhysicalRow: Equatable, Sendable {
    public let rowID: UInt64
    public let relationIndex: Int
    public let componentIndex: Int
    public let kind: GeometricRelation.Kind
    public let normalizationScale: Double
    /// Retained planar coincidence z equation. It carries no out-of-plane force authority.
    public let isStructuralZero: Bool
    public let first: GeometricRowEndpointCovector
    public let second: GeometricRowEndpointCovector
    internal init(rowID: UInt64, relationIndex: Int, componentIndex: Int, kind: GeometricRelation.Kind,
                  normalizationScale: Double, isStructuralZero: Bool,
                  first: GeometricRowEndpointCovector, second: GeometricRowEndpointCovector) {
        self.rowID = rowID; self.relationIndex = relationIndex; self.componentIndex = componentIndex; self.kind = kind
        self.normalizationScale = normalizationScale; self.isStructuralZero = isStructuralZero; self.first = first; self.second = second
    }
}
