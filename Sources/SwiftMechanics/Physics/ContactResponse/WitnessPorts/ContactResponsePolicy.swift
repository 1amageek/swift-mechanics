public struct ContactResponsePolicy: Sendable {
    public let maximumContacts: Int, maximumColliders: Int, maximumBodies: Int, maximumVelocities: Int
    public let lengthTolerance: Double, normalTolerance: Double
    public let forceScale: Double, lengthScale: Double, powerScale: Double, originalTolerance: Double
    public let dynamics: DynamicsSolvePolicy
    public let law: ContactAcceptancePolicy
    public let coneTolerance: ConeTolerance
    public let precision: NumericalPrecision, backend: NumericalBackend
    public let maximumConeIterations: Int, conePivotThreshold: Double
    public let isCancelled: @Sendable () -> Bool
    public init(maximumContacts: Int, maximumColliders: Int, maximumBodies: Int, maximumVelocities: Int,
                lengthTolerance: Double, normalTolerance: Double, forceScale: Double, lengthScale: Double, powerScale: Double,
                originalTolerance: Double, dynamics: DynamicsSolvePolicy, law: ContactAcceptancePolicy, coneTolerance: ConeTolerance,
                precision: NumericalPrecision, backend: NumericalBackend, maximumConeIterations: Int, conePivotThreshold: Double,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(ContactResponseError) {
        guard maximumContacts > 0, maximumColliders > 0, maximumBodies > 0, maximumVelocities > 0,
              lengthTolerance.isFinite, lengthTolerance >= 0, normalTolerance.isFinite, normalTolerance >= 0,
              forceScale.isFinite, forceScale > 0, lengthScale.isFinite, lengthScale > 0, powerScale.isFinite, powerScale > 0,
              originalTolerance.isFinite, originalTolerance >= 0, maximumConeIterations >= 0, conePivotThreshold.isFinite, conePivotThreshold >= 0,
              (forceScale/lengthScale).isFinite, forceScale/lengthScale > 0, (forceScale*lengthScale).isFinite, forceScale*lengthScale > 0 else { throw .invalidInput }
        self.maximumContacts=maximumContacts; self.maximumColliders=maximumColliders; self.maximumBodies=maximumBodies; self.maximumVelocities=maximumVelocities
        self.lengthTolerance=lengthTolerance; self.normalTolerance=normalTolerance; self.forceScale=forceScale; self.lengthScale=lengthScale
        self.powerScale=powerScale; self.originalTolerance=originalTolerance; self.dynamics=dynamics; self.law=law; self.coneTolerance=coneTolerance
        self.precision=precision; self.backend=backend; self.maximumConeIterations=maximumConeIterations; self.conePivotThreshold=conePivotThreshold; self.isCancelled=isCancelled
    }
}
