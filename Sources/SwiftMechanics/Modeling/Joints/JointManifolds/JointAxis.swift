
public struct JointAxis: Equatable, Sendable {
    public let kind: JointAxisKind
    public let direction: Vector3
    public let pitchMetersPerRadian: Double

    public init(kind: JointAxisKind, direction: Vector3, pitchMetersPerRadian: Double = 0) throws {
        guard direction != .zero else { throw JointError.invalidAxis }
        guard pitchMetersPerRadian.isFinite,
              kind == .screw || pitchMetersPerRadian == 0 else { throw JointError.invalidJointGeometry }
        self.kind = kind
        self.direction = try direction.normalized()
        self.pitchMetersPerRadian = pitchMetersPerRadian
    }

    internal func generator() throws -> SpatialMotion {
        switch kind {
        case .revolute: return SpatialMotion(angular: direction, linear: .zero)
        case .prismatic: return SpatialMotion(angular: .zero, linear: direction)
        case .screw: return SpatialMotion(angular: direction, linear: try direction.scaled(by: pitchMetersPerRadian))
        }
    }

    internal func pose(coordinate: Double) throws -> RigidTransform {
        switch kind {
        case .revolute: return RigidTransform(rotation: try UnitQuaternion(axis: direction, angle: coordinate), translation: .zero)
        case .prismatic: return RigidTransform(rotation: .identity, translation: try direction.scaled(by: coordinate))
        case .screw:
            return RigidTransform(rotation: try UnitQuaternion(axis: direction, angle: coordinate),
                                  translation: try direction.scaled(by: pitchMetersPerRadian * coordinate))
        }
    }
}
