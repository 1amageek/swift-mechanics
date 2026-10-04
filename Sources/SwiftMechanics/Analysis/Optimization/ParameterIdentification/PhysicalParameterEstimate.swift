public struct PhysicalParameterEstimate: Sendable {
    public let source: PrismaticIdentificationSource
    public let metadata: OptimizationMetadata
    public let massKilograms: Double
    public let dampingNewtonSecondsPerMeter: Double
    public let lowerBounds: [Double]
    public let upperBounds: [Double]
    public let objective: Double
    public let originalForceResidualsNewtons: [Double]
    public let normalizedInformationMatrix: [Double]
    /// Reference covariance of the UNBOUNDED affine Gaussian estimator, not the bounded estimate's covariance.
    public let unconstrainedGaussianReferenceCovariance: [Double]
    public let identifiableNormalizedDirections: [Double]
    public let activeLowerBounds: [Bool]
    public let activeUpperBounds: [Bool]
    public let optimizationCertificate: OptimizationCertificate
    public let originalGradient: [Double]
    public let originalStationarityResidual: Double
    public let originalInformationResidual: Double
    public let noiseAssumption: IdentificationNoiseAssumption
    public let work: NumericalWork
    public let loadWork: LoadWork
    public let supplierWork: DerivativeSupplierWork
    public let modelValidationAttempts: Int
}
