public struct ContactResolvedParameters: Equatable, Sendable {
    public let normal: ContactNormalLaw
    public let friction: ContactFrictionLaw
    public let resistance: ContactResistanceParameters
    public let resistanceRadius: Double
    public let cohesion: ContactCohesionLaw
    public init(normal: ContactNormalLaw, friction: ContactFrictionLaw, resistance: ContactResistanceParameters,
                resistanceRadius: Double, cohesion: ContactCohesionLaw) throws(ContactLawError) {
        try normal.validate(); try cohesion.validate()
        guard resistanceRadius.isFinite, resistanceRadius > 0 else { throw .invalidMaterial }
        self.normal=normal; self.friction=friction; self.resistance=resistance; self.resistanceRadius=resistanceRadius; self.cohesion=cohesion
    }
}
