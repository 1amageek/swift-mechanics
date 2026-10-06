public struct CapstanResponse: Equatable, Sendable {
    /// The tension upstream of positive cable travel and the downstream tension.
    public let upstreamTension: Double, downstreamTension: Double, slipSpeed: Double
    /// Signed net tension force on the traveling cable and dissipated power.
    public let cableForce: Double, dissipatedPower: Double, sticking: Bool
}
