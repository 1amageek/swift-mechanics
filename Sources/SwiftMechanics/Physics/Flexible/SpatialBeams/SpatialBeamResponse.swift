public struct SpatialBeamResponse: Equatable, Sendable {
    public let beam: SpatialBeamDefinition
    public let strainEnergy: Double
    public let kineticEnergy: Double
    public let elasticPower: Double
    public let dampingDissipation: Double
    public let energyGradient: [Double]
    public let elasticRestoringForce: [Double]
    public let dampingForce: [Double]
    /// d(energyGradient)/dq in the reference frame; d(restoringForce)/dq is its negative.
    public let positiveEnergyTangent: [Double]
    internal init(beam: SpatialBeamDefinition, strainEnergy: Double, kineticEnergy: Double,
                  elasticPower: Double, dampingDissipation: Double, energyGradient: [Double],
                  elasticRestoringForce: [Double], dampingForce: [Double], positiveEnergyTangent: [Double]) {
        self.beam = beam; self.strainEnergy = strainEnergy; self.kineticEnergy = kineticEnergy
        self.elasticPower = elasticPower; self.dampingDissipation = dampingDissipation
        self.energyGradient = energyGradient; self.elasticRestoringForce = elasticRestoringForce
        self.dampingForce = dampingForce; self.positiveEnergyTangent = positiveEnergyTangent
    }
}
