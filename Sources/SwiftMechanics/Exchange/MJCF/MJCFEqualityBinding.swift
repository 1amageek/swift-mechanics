public struct MJCFEqualityBinding: Sendable {
    public let name: String
    public let node: Int
    public let rowID: UInt64
    public let entity: EntityID
    public let constantSI: Double
    public let gradientSI: [Double]
    public let residualScale: Double
    public let effectiveAttributes: [MJCFEffectiveAttribute]
    internal init(name: String, node: Int, rowID: UInt64, entity: EntityID, constantSI: Double, gradientSI: [Double], residualScale: Double, effectiveAttributes: [MJCFEffectiveAttribute]) {
        self.name = name; self.node = node; self.rowID = rowID; self.entity = entity; self.effectiveAttributes = effectiveAttributes
        self.constantSI = constantSI; self.gradientSI = gradientSI; self.residualScale = residualScale
    }
}
