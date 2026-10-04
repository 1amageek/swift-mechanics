public final class SurfaceContactWitness: Sendable {
    public let snapshot: DeformingSurfaceSnapshot
    public let first: SurfaceMaterialPoint
    public let second: SurfaceMaterialPoint?
    public let obstacle: CollisionProxy?
    public let secondBody: ModelReference
    public let pointA: Vector3, pointB: Vector3, normal: Vector3
    public let separation: Double
    public let contactRotation: UnitQuaternion
    internal init(snapshot: DeformingSurfaceSnapshot, first: SurfaceMaterialPoint, second: SurfaceMaterialPoint?, obstacle: CollisionProxy?,
                  secondBody: ModelReference, pointA: Vector3, pointB: Vector3, normal: Vector3, separation: Double, rotation: UnitQuaternion) {
        self.snapshot=snapshot; self.first=first; self.second=second; self.obstacle=obstacle; self.secondBody=secondBody
        self.pointA=pointA; self.pointB=pointB; self.normal=normal; self.separation=separation; contactRotation=rotation
    }
}
