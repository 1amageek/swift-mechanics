import MechanicsCore
import MechanicsModel
public struct RigidPressurePlane: Sendable {
    public let body: ModelReference, frame: ModelReference
    public let revision: UInt64
    public let point: Vector3, normal: Vector3
    /// Actual rigid velocity about point, including any prescribed drift.
    public let velocityAboutPoint: SpatialMotion
    public init(body: ModelReference, frame: ModelReference, revision: UInt64, point: Vector3, normal: Vector3, velocityAboutPoint: SpatialMotion) {
        self.body=body; self.frame=frame; self.revision=revision; self.point=point; self.normal=normal; self.velocityAboutPoint=velocityAboutPoint
    }
}
