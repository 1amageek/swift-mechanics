/// Targets use the immutable world frame; local points use the identified body's own frame.
public enum PoseIKTask: Sendable {
    case point(rowIDs: [UInt64], body: EntityID, bodyFrame: EntityID, localPoint: Vector3,
               targetWorld: Vector3, lengthScale: Double, toleranceMeters: Double)
    case orientation(rowIDs: [UInt64], body: EntityID, bodyFrame: EntityID, targetWorld: UnitQuaternion,
                     angularScale: Double, matrixTolerance: Double)
    case pose(rowIDs: [UInt64], body: EntityID, bodyFrame: EntityID, localPoint: Vector3,
              targetWorld: RigidTransform, lengthScale: Double, angularScale: Double,
              toleranceMeters: Double, matrixTolerance: Double)
    // FIXME(INCOMPLETE_IMPLEMENTATION): Collision task equations are unavailable in PoseIKSolving.solve; this case must fail until actual collision derivatives and original geometry acceptance are qualified.
    case collision(rowIDs: [UInt64])

    public var rowIDs: [UInt64] {
        switch self {
        case .point(let ids, _, _, _, _, _, _), .orientation(let ids, _, _, _, _, _),
             .pose(let ids, _, _, _, _, _, _, _, _), .collision(let ids): return ids
        }
    }
}
