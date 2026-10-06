public struct ParticleFlowPolicy: Equatable, Sendable {
    public let budget: NumericalBudget
    public let maximumMetadataBytes: Int
    public let minimumSeparation: Double
    public let maximumRelativeDensityDeviation: Double
    public let maximumMach: Double
    public let courantFactor: Double
    public let viscousFactor: Double
    public let accelerationFactor: Double
    public let maximumDensityChangeFraction: Double
    public let densityRate: ParticleFlowResidualScale
    public let force: ParticleFlowResidualScale
    public let power: ParticleFlowResidualScale
    public let momentum: ParticleFlowResidualScale
    public let energy: ParticleFlowResidualScale
    public init(budget: NumericalBudget, maximumMetadataBytes: Int, minimumSeparation: Double,
                maximumRelativeDensityDeviation: Double, maximumMach: Double,
                courantFactor: Double, viscousFactor: Double, accelerationFactor: Double,
                maximumDensityChangeFraction: Double, densityRate: ParticleFlowResidualScale,
                force: ParticleFlowResidualScale, power: ParticleFlowResidualScale,
                momentum: ParticleFlowResidualScale, energy: ParticleFlowResidualScale) throws(ParticleFlowError) {
        guard maximumMetadataBytes > 0, minimumSeparation.isFinite, minimumSeparation > 0,
              maximumRelativeDensityDeviation.isFinite, maximumRelativeDensityDeviation > 0,
              maximumRelativeDensityDeviation <= 0.1, maximumMach.isFinite, maximumMach > 0, maximumMach <= 0.3,
              courantFactor.isFinite, courantFactor > 0, courantFactor <= 0.5,
              viscousFactor.isFinite, viscousFactor > 0, viscousFactor <= 0.5,
              accelerationFactor.isFinite, accelerationFactor > 0, accelerationFactor <= 0.5,
              maximumDensityChangeFraction.isFinite, maximumDensityChangeFraction > 0,
              maximumDensityChangeFraction <= 0.1 else { throw .invalidPolicy }
        self.budget = budget; self.maximumMetadataBytes = maximumMetadataBytes; self.minimumSeparation = minimumSeparation
        self.maximumRelativeDensityDeviation = maximumRelativeDensityDeviation; self.maximumMach = maximumMach
        self.courantFactor = courantFactor; self.viscousFactor = viscousFactor; self.accelerationFactor = accelerationFactor
        self.maximumDensityChangeFraction = maximumDensityChangeFraction
        self.densityRate = densityRate; self.force = force; self.power = power
        self.momentum = momentum; self.energy = energy
    }
}
