import MechanicsCore
/// Force components in N. Classification is independent of prescribed kinematic drift.
public struct ForceParts: Equatable, Sendable {
    public let conservative: Vector3
    public let dissipative: Vector3
    public let active: Vector3
    public init(conservative: Vector3 = .zero, dissipative: Vector3 = .zero, active: Vector3 = .zero) {
        self.conservative = conservative; self.dissipative = dissipative; self.active = active
    }
    public func total() throws(LoadError) -> Vector3 {
        try loadCore { () throws(CoreError) in try conservative.adding(dissipative).adding(active) }
    }
    public func rotated(by rotation: UnitQuaternion) throws(LoadError) -> ForceParts {
        try loadCore { () throws(CoreError) in try ForceParts(conservative: rotation.rotating(conservative),
            dissipative: rotation.rotating(dissipative), active: rotation.rotating(active)) }
    }
}
