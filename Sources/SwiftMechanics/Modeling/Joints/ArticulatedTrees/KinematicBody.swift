
public struct KinematicBody: Equatable, Sendable {
    public let id: EntityID
    public let frame: EntityID
    public let referencePose: RigidTransform
    public let dimension: KinematicDimension

    public init(body: BodyRecord3D) {
        id = body.id; frame = body.frame; referencePose = body.bodyToWorld; dimension = .spatial
    }

    public init(body: BodyRecord2D) throws {
        id = body.id; frame = body.frame; dimension = .planar
        referencePose = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: body.bodyToWorld.angle),
                                       translation: try Vector3(body.bodyToWorld.x, body.bodyToWorld.y, 0))
    }
}
