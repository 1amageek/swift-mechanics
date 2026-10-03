import MechanicsCore
import MechanicsModel
/// SI impulse (Ns), deliberately distinct from force. No momentum update is performed here.
public struct FramedImpulse: Equatable, Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let point: Vector3
    public let impulse: Vector3
    public let angularImpulse: Vector3
    public init(body: EntityID, frame: EntityID, point: Vector3, impulse: Vector3,
                angularImpulse: Vector3 = .zero) throws(LoadError) {
        guard body.kind == .body, frame.kind == .frame else { throw .invalidInput }
        self.body = body; self.frame = frame; self.point = point
        self.impulse = impulse; self.angularImpulse = angularImpulse
    }
    public func equivalent(about referencePoint: Vector3) throws(LoadError) -> SpatialWrench {
        let torque = try loadCore { () throws(CoreError) in try point.subtracting(referencePoint).cross(impulse).adding(angularImpulse) }
        return SpatialWrench(torque: torque, force: impulse)
    }
}
