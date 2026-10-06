public struct IdentificationPolicy: Sendable {
    public let maximumObservations: Int
    public let maximumMetadataBytes: Int
    public let maximumModelValidationAttempts: Int
    public let rankThreshold: Double
    public let physicalAgreement: NumericalTolerance
    public let normalizedAgreement: NumericalTolerance
    public let informationAgreement: NumericalTolerance
    public let joint: JointEvaluationPolicy
    public let dynamics: DynamicsAdmission
    public let derivative: DerivativePolicy
    public let inertiaValidation: InertiaValidationPolicy
    public let optimization: OptimizationPolicy
    public let informationCapability: LinearCapability
    public let informationTolerance: LinearTolerance<Double>
    public let isCancelled: @Sendable () -> Bool
    public init(maximumObservations: Int, maximumMetadataBytes: Int, maximumModelValidationAttempts: Int,
                rankThreshold: Double, physicalAgreement: NumericalTolerance, normalizedAgreement: NumericalTolerance,
                informationAgreement: NumericalTolerance, joint: JointEvaluationPolicy, dynamics: DynamicsAdmission,
                derivative: DerivativePolicy, inertiaValidation: InertiaValidationPolicy, optimization: OptimizationPolicy,
                informationCapability: LinearCapability, informationTolerance: LinearTolerance<Double>,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(IdentificationCause) {
        guard maximumObservations > 0, maximumMetadataBytes >= 0, maximumModelValidationAttempts >= 0,
              rankThreshold.isFinite, rankThreshold >= 0 else { throw .invalidSource }
        self.maximumObservations=maximumObservations; self.maximumMetadataBytes=maximumMetadataBytes
        self.maximumModelValidationAttempts=maximumModelValidationAttempts; self.rankThreshold=rankThreshold
        self.physicalAgreement=physicalAgreement; self.normalizedAgreement=normalizedAgreement; self.informationAgreement=informationAgreement
        self.joint=joint; self.dynamics=dynamics; self.derivative=derivative; self.inertiaValidation=inertiaValidation
        self.optimization=optimization; self.informationCapability=informationCapability; self.informationTolerance=informationTolerance
        self.isCancelled=isCancelled
    }
}
