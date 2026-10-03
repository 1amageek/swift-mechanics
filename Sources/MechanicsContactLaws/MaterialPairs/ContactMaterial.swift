import MechanicsModel
public struct ContactMaterial: Equatable, Sendable {
    public let reference: ModelReference
    public let youngModulus: Double, poissonsRatio: Double
    public let linearStiffness: Double, normalDamping: Double, huntCrossleyAlpha: Double
    public let friction: ContactFrictionLaw
    public let resistance: ContactResistanceParameters
    public let cohesion: ContactCohesionLaw
    public init(reference: ModelReference, youngModulus: Double, poissonsRatio: Double,
                linearStiffness: Double, normalDamping: Double, huntCrossleyAlpha: Double,
                friction: ContactFrictionLaw, resistance: ContactResistanceParameters, cohesion: ContactCohesionLaw) throws(ContactLawError) {
        guard reference.id.kind == .material else { throw .invalidIdentity }
        guard youngModulus.isFinite, youngModulus > 0, poissonsRatio.isFinite, poissonsRatio > -1, poissonsRatio < 0.5,
              linearStiffness.isFinite, linearStiffness > 0, normalDamping.isFinite, normalDamping >= 0,
              huntCrossleyAlpha.isFinite, huntCrossleyAlpha >= 0 else { throw .invalidMaterial }
        try cohesion.validate()
        self.reference=reference; self.youngModulus=youngModulus; self.poissonsRatio=poissonsRatio
        self.linearStiffness=linearStiffness; self.normalDamping=normalDamping; self.huntCrossleyAlpha=huntCrossleyAlpha
        self.friction=friction; self.resistance=resistance; self.cohesion=cohesion
    }
}
