import MechanicsCore
import MechanicsModel
public struct EquivalentLoad: Equatable, Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let referencePoint: Vector3
    public let wrench: SpatialWrench
    public let potentialEnergy: Double?
    public let explicitPotentialTimeDerivative: Double?
    internal init(body: EntityID, frame: EntityID, referencePoint: Vector3, wrench: SpatialWrench,
                  potentialEnergy: Double?, explicitPotentialTimeDerivative: Double?) {
        self.body = body; self.frame = frame; self.referencePoint = referencePoint; self.wrench = wrench
        self.potentialEnergy = potentialEnergy; self.explicitPotentialTimeDerivative = explicitPotentialTimeDerivative
    }
}
