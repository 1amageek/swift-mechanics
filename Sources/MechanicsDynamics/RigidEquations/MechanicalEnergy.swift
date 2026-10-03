import MechanicsCore
import MechanicsModel
public struct MechanicalEnergy: Equatable, Sendable {
    public let time: Double
    public let frame: EntityID
    public let angularMomentumReference: Vector3
    public let gravityExplicitPotentialTimeDerivative: Double
    public let kineticEnergy: Double
    public let potentialEnergy: Double?
    public let dissipatedPower: Double?
    public let linearMomentum: Vector3
    public let angularMomentum: Vector3
    public let kineticEnergyRate: Double
    public let requiredVirtualPower: Double
    public let requiredPrescribedPower: Double
    internal init(time: Double, frame: EntityID, angularMomentumReference: Vector3, gravityExplicitPotentialTimeDerivative: Double, kineticEnergy: Double,
                  potentialEnergy: Double?, dissipatedPower: Double?, linearMomentum: Vector3, angularMomentum: Vector3,
                  kineticEnergyRate: Double, requiredVirtualPower: Double, requiredPrescribedPower: Double) {
        self.time = time; self.frame = frame; self.angularMomentumReference = angularMomentumReference
        self.gravityExplicitPotentialTimeDerivative = gravityExplicitPotentialTimeDerivative
        self.kineticEnergy = kineticEnergy; self.potentialEnergy = potentialEnergy; self.dissipatedPower = dissipatedPower
        self.linearMomentum = linearMomentum; self.angularMomentum = angularMomentum
        self.kineticEnergyRate = kineticEnergyRate; self.requiredVirtualPower = requiredVirtualPower
        self.requiredPrescribedPower = requiredPrescribedPower
    }
}
