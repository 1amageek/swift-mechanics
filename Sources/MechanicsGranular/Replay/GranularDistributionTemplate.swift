import MechanicsModel
public struct GranularDistributionTemplate: Sendable {
    public let weight: UInt64
    public let radius: Double, density: Double
    public let material: ModelReference
    public init(weight: UInt64, radius: Double, density: Double, material: ModelReference) throws(GranularError) {
        guard weight > 0, radius.isFinite, radius > 0, density.isFinite, density > 0, material.id.kind == .material else { throw .invalidInput }
        self.weight=weight; self.radius=radius; self.density=density; self.material=material
    }
}
