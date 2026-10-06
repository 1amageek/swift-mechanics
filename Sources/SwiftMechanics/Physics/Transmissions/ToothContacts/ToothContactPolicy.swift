public struct ToothContactPolicy: Sendable {
    public let maximumTeeth: Int
    public let maximumContacts: Int
    public let maximumIdentifierBytes: Int
    public let maximumSteps: Int
    public let maximumFeatureSpacingMeters: Double
    public let maximumEnergyDefect: Double
    public let physicalTolerance: Double
    public let collision: CollisionQueryPolicy
    public let contact: ContactAcceptancePolicy
    public let dynamics: DynamicsSolvePolicy
    public let admission: DynamicsAdmission
    public let isCancelled: @Sendable () -> Bool
    public init(maximumTeeth: Int, maximumContacts: Int, maximumIdentifierBytes: Int, maximumSteps: Int,
                maximumFeatureSpacingMeters: Double, maximumEnergyDefect: Double, physicalTolerance: Double,
                collision: CollisionQueryPolicy, contact: ContactAcceptancePolicy, dynamics: DynamicsSolvePolicy,
                admission: DynamicsAdmission, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(ToothContactError) {
        guard maximumTeeth > 0, maximumContacts > 0, maximumIdentifierBytes >= 0, maximumSteps >= 0,
              maximumFeatureSpacingMeters.isFinite, maximumFeatureSpacingMeters > 0,
              maximumEnergyDefect.isFinite, maximumEnergyDefect >= 0, physicalTolerance.isFinite, physicalTolerance >= 0 else { throw .invalidInput }
        self.maximumTeeth=maximumTeeth; self.maximumContacts=maximumContacts; self.maximumIdentifierBytes=maximumIdentifierBytes
        self.maximumSteps=maximumSteps; self.maximumFeatureSpacingMeters=maximumFeatureSpacingMeters
        self.maximumEnergyDefect=maximumEnergyDefect; self.physicalTolerance=physicalTolerance
        self.collision=collision; self.contact=contact; self.dynamics=dynamics; self.admission=admission; self.isCancelled=isCancelled
    }
}
