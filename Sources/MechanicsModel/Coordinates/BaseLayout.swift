import MechanicsCore

public enum BaseLayout: Equatable, Sendable {
    case fixed, planarFloating, spatialFloating

    public var positionCount: Int {
        switch self { case .fixed: 0; case .planarFloating: 3; case .spatialFloating: 7 }
    }
    public var velocityCount: Int {
        switch self { case .fixed: 0; case .planarFloating: 3; case .spatialFloating: 6 }
    }

    public func encode(_ state: BaseState) throws -> BaseCoordinates {
        switch (self, state) {
        case (.fixed, .fixed): return try BaseCoordinates(q: [], v: [])
        case (.planarFloating, .planar(let pose, let vx, let vy, let omega)):
            return try BaseCoordinates(q: [pose.x, pose.y, pose.angle], v: [vx, vy, omega])
        case (.spatialFloating, .spatial(let pose, let linear, let angular)):
            let q = pose.rotation
            return try BaseCoordinates(q: [pose.translation.x, pose.translation.y, pose.translation.z, q.w, q.x, q.y, q.z],
                                       v: [linear.x, linear.y, linear.z, angular.x, angular.y, angular.z])
        default: throw ModelError.invalidLayout
        }
    }

    public func decode(_ coordinates: BaseCoordinates, quaternionTolerance: NumericalTolerance) throws -> BaseState {
        let q = coordinates.q, v = coordinates.v
        guard q.count == positionCount, v.count == velocityCount else { throw ModelError.invalidLayout }
        switch self {
        case .fixed: return .fixed
        case .planarFloating:
            return .planar(pose: try PlanarPose(x: q[0], y: q[1], angle: q[2]),
                           worldVelocityX: v[0], worldVelocityY: v[1], angularVelocityZ: v[2])
        case .spatialFloating:
            let scale = max(abs(q[3]), max(abs(q[4]), max(abs(q[5]), abs(q[6]))))
            guard scale > 0 else { throw ModelError.invalidQuaternion }
            let norm = scale * ((q[3] / scale) * (q[3] / scale) + (q[4] / scale) * (q[4] / scale)
                + (q[5] / scale) * (q[5] / scale) + (q[6] / scale) * (q[6] / scale)).squareRoot()
            guard norm.isFinite, try quaternionTolerance.contains(error: norm - 1, scale: 1) else {
                throw ModelError.invalidQuaternion
            }
            return .spatial(pose: RigidTransform(rotation: try UnitQuaternion(w: q[3], x: q[4], y: q[5], z: q[6]),
                                                  translation: try Vector3(q[0], q[1], q[2])),
                            worldLinearVelocity: try Vector3(v[0], v[1], v[2]),
                            bodyAngularVelocity: try Vector3(v[3], v[4], v[5]))
        }
    }
}
