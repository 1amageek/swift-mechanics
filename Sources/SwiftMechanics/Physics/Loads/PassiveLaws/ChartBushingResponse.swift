/// Loads conjugate to independent [rotation rad, translation m] chart coordinates.
/// These are not finite-angle spatial wrench components.
public struct ChartBushingResponse: Equatable, Sendable {
    public let frame: EntityID
    public let conservative: [Double]
    public let dissipative: [Double]
    public let potentialEnergy: Double
    public let dissipatedPower: Double
    internal init(frame: EntityID, conservative: [Double], dissipative: [Double], potentialEnergy: Double, dissipatedPower: Double) {
        self.frame = frame
        self.conservative = conservative; self.dissipative = dissipative
        self.potentialEnergy = potentialEnergy; self.dissipatedPower = dissipatedPower
    }
}
