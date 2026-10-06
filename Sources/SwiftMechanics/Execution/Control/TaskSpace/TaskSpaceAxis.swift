/// Cartesian axis in the declared world frame.
public enum TaskSpaceAxis: Int, CaseIterable, Sendable {
    case x, y, z
    internal func component(_ value: Vector3) -> Double {
        switch self { case .x: value.x; case .y: value.y; case .z: value.z }
    }
}
