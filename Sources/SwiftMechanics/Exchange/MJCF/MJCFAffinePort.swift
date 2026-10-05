/// Physical affine length/angle with an actual qualified power transmission.
public struct MJCFAffinePort: Sendable {
    public let name: String
    public let node: Int
    public let entity: EntityID
    public let referenceOffset: Double
    public let transmission: AffineTransmission
    public let effectiveAttributes: [MJCFEffectiveAttribute]
    internal init(name: String, node: Int, entity: EntityID, referenceOffset: Double, transmission: AffineTransmission, effectiveAttributes: [MJCFEffectiveAttribute]) {
        self.name = name; self.node = node; self.entity = entity; self.referenceOffset = referenceOffset; self.transmission = transmission; self.effectiveAttributes = effectiveAttributes
    }
}
