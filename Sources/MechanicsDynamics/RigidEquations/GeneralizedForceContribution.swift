public struct GeneralizedForceContribution: Equatable, Sendable {
    public let values: [Double]
    public let channel: ForceChannel
    public let potentialEnergy: Double?
    public let dissipatedPower: Double?
    public init(values: [Double], channel: ForceChannel, potentialEnergy: Double? = nil,
                dissipatedPower: Double? = nil) throws(DynamicsError) {
        guard values.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        if let e = potentialEnergy { guard e.isFinite else { throw .invalidInput } }
        if let d = dissipatedPower { guard d.isFinite, d >= 0 else { throw .invalidInput } }
        self.values = values; self.channel = channel; self.potentialEnergy = potentialEnergy; self.dissipatedPower = dissipatedPower
    }
}
