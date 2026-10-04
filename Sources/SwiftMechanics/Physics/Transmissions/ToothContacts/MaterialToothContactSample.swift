public final class MaterialToothContactSample: Sendable {
    public let pair: ToothContactPair
    public let witness: CollisionWitness
    public let applicationPoint: Vector3
    public let basis: ContactBasis
    public let relativePointVelocity: Vector3
    public let relativeAngularVelocity: Vector3
    public let slipVelocity: Vector3
    public let evidence: MaterialToothContactEvidence
    public let forceOnB: Vector3
    public let coupleOnB: Vector3
    public let torqueAtFirstBodyOrigin: Vector3
    public let torqueAtSecondBodyOrigin: Vector3
    public let normalStoredEnergy: Double
    public let tangentialStoredEnergy: Double
    public let cohesivePotentialEnergy: Double
    public let completeCohesiveSeparationWork: Double
    public let normalDissipationPower: Double
    public let resistanceDissipationPower: Double
    public let tangentialDissipationEnergy: Double
    public let relativeMechanicalPower: Double
    internal init(pair: ToothContactPair, witness: CollisionWitness, applicationPoint: Vector3, basis: ContactBasis,
                  relative: Vector3, angular: Vector3, slip: Vector3, evidence: MaterialToothContactEvidence,
                  current: ContactCurrentResponse, tangentLoss: Double, firstTorque: Vector3, secondTorque: Vector3) {
        self.pair=pair; self.witness=witness; self.applicationPoint=applicationPoint; self.basis=basis
        relativePointVelocity=relative; relativeAngularVelocity=angular; slipVelocity=slip; self.evidence=evidence
        forceOnB=current.forceOnB; coupleOnB=current.coupleOnB
        torqueAtFirstBodyOrigin=firstTorque; torqueAtSecondBodyOrigin=secondTorque
        normalStoredEnergy=current.normalStoredEnergy; tangentialStoredEnergy=current.tangentialStoredEnergy
        cohesivePotentialEnergy=current.cohesivePotentialEnergy; completeCohesiveSeparationWork=current.completeCohesiveSeparationWork
        normalDissipationPower=current.normalDissipationPower; resistanceDissipationPower=current.resistanceDissipationPower
        tangentialDissipationEnergy=tangentLoss; relativeMechanicalPower=current.relativeMechanicalPower
    }
}
