
public protocol KinematicJacobianComputing: Sendable {
    func geometric(body: EntityID, snapshot: KinematicSnapshot) throws -> KinematicJacobian
    func spatial(body: EntityID, snapshot: KinematicSnapshot) throws -> KinematicJacobian
    func point(body: EntityID, bodyLocalPoint: Vector3, snapshot: KinematicSnapshot) throws -> PointJacobian
    func pointMotion(body: EntityID, bodyLocalPoint: Vector3, snapshot: KinematicSnapshot) throws -> PointKinematics
}
