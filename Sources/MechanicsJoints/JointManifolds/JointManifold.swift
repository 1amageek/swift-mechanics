import MechanicsCore

public struct JointManifold: Equatable, Sendable {
    public let kind: JointKind
    public let orderedAxes: [JointAxis]
    public let positionCount: Int
    public let velocityCount: Int

    public init(_ specification: JointSpecification) throws {
        let axes: [JointAxis]
        let kind: JointKind
        switch specification {
        case .fixed: kind = .fixed; axes = []
        case .revolute(let axis): kind = .revolute; axes = [try JointAxis(kind: .revolute, direction: axis)]
        case .prismatic(let axis): kind = .prismatic; axes = [try JointAxis(kind: .prismatic, direction: axis)]
        case .spherical: kind = .spherical; axes = []
        case .universal(let first, let second):
            kind = .universal
            let a = try JointAxis(kind: .revolute, direction: first), b = try JointAxis(kind: .revolute, direction: second)
            guard try a.direction.cross(b.direction).magnitude() > 0 else { throw JointError.invalidJointGeometry }
            axes = [a, b]
        case .cylindrical(let axis):
            kind = .cylindrical
            axes = [try JointAxis(kind: .prismatic, direction: axis), try JointAxis(kind: .revolute, direction: axis)]
        case .planar(let first, let second):
            kind = .planar
            let a = try JointAxis(kind: .prismatic, direction: first), b = try JointAxis(kind: .prismatic, direction: second)
            let normal = try a.direction.cross(b.direction)
            guard try normal.magnitude() > 0 else { throw JointError.invalidJointGeometry }
            axes = [a, b, try JointAxis(kind: .revolute, direction: normal)]
        case .screw(let axis, let pitch):
            kind = .screw; axes = [try JointAxis(kind: .screw, direction: axis, pitchMetersPerRadian: pitch)]
        case .sixDOF: kind = .sixDOF; axes = []
        case .custom(let ordered):
            guard ordered.count <= 6 else { throw JointError.invalidJointGeometry }
            kind = .custom; axes = ordered
        }
        self.kind = kind
        self.orderedAxes = axes
        switch kind {
        case .spherical: positionCount = 4; velocityCount = 3
        case .sixDOF: positionCount = 7; velocityCount = 6
        default: positionCount = axes.count; velocityCount = axes.count
        }
    }

    public var preservesWorldXYPlane: Bool {
        if kind == .spherical || kind == .sixDOF { return false }
        return orderedAxes.allSatisfy { axis in
            switch axis.kind {
            case .prismatic: axis.direction.z == 0
            case .revolute: axis.direction.x == 0 && axis.direction.y == 0
            case .screw: axis.direction.x == 0 && axis.direction.y == 0 && axis.pitchMetersPerRadian == 0
            }
        }
    }
}
