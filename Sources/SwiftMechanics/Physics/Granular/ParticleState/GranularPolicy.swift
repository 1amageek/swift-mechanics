public struct GranularPolicy: Sendable {
    public let maximumParticles: Int, maximumBoundaries: Int, maximumContacts: Int, maximumNeighbors: Int
    public let momentumTolerance: Double, angularMomentumTolerance: Double, energyTolerance: Double
    public let referenceMomentum: Double, referenceAngularMomentum: Double, referenceEnergy: Double, relativeTolerance: Double
    public let minimumTransportDot: Double
    public let collision: CollisionQueryPolicy
    public let contact: ContactAcceptancePolicy
    public let isCancelled: @Sendable () -> Bool
    public init(maximumParticles: Int, maximumBoundaries: Int, maximumContacts: Int, maximumNeighbors: Int,
        momentumTolerance: Double, angularMomentumTolerance: Double, energyTolerance: Double,
        referenceMomentum: Double, referenceAngularMomentum: Double, referenceEnergy: Double, relativeTolerance: Double,
        minimumTransportDot: Double, collision: CollisionQueryPolicy, contact: ContactAcceptancePolicy, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(GranularError) {
        guard minimumTransportDot.isFinite, minimumTransportDot > -1, minimumTransportDot < 1, maximumParticles > 0, maximumBoundaries >= 0, maximumContacts >= 0, maximumNeighbors >= 0,
            momentumTolerance.isFinite, momentumTolerance >= 0, angularMomentumTolerance.isFinite, angularMomentumTolerance >= 0,
            energyTolerance.isFinite, energyTolerance >= 0, relativeTolerance.isFinite, relativeTolerance >= 0,
            referenceMomentum.isFinite, referenceMomentum > 0, referenceAngularMomentum.isFinite, referenceAngularMomentum > 0,
            referenceEnergy.isFinite, referenceEnergy > 0 else { throw .invalidInput }
        self.maximumParticles=maximumParticles; self.maximumBoundaries=maximumBoundaries; self.maximumContacts=maximumContacts; self.maximumNeighbors=maximumNeighbors
        self.momentumTolerance=momentumTolerance; self.angularMomentumTolerance=angularMomentumTolerance; self.energyTolerance=energyTolerance
        self.referenceMomentum=referenceMomentum; self.referenceAngularMomentum=referenceAngularMomentum; self.referenceEnergy=referenceEnergy; self.relativeTolerance=relativeTolerance
        self.minimumTransportDot=minimumTransportDot; self.collision=collision; self.contact=contact; self.isCancelled=isCancelled
    }
}
