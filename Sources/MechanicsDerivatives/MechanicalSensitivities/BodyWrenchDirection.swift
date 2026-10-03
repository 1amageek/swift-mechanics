import MechanicsCore
import MechanicsModel
public struct BodyWrenchDirection: Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let referencePoint: Vector3
    public let wrench: SpatialWrench
    public init(body: EntityID, frame: EntityID, referencePoint: Vector3 = .zero,
                wrench: SpatialWrench = SpatialWrench(torque:.zero,force:.zero)) {
        self.body=body; self.frame=frame; self.referencePoint=referencePoint; self.wrench=wrench
    }
}
