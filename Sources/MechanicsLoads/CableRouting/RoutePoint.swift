import MechanicsCore
import MechanicsModel
/// Position derivatives with respect to independent affine coordinates; no nonlinear joint Hessian is implied.
public struct RoutePoint: Equatable, Sendable {
    public let frame: EntityID
    public let position: Vector3
    public let coordinateColumns: [Vector3]
    public let prescribedVelocity: Vector3
    public init(frame: EntityID, position: Vector3, coordinateColumns: [Vector3], prescribedVelocity: Vector3 = .zero) throws(LoadError) {
        guard frame.kind == .frame else { throw .invalidInput }
        self.frame = frame; self.position = position; self.coordinateColumns = coordinateColumns
        self.prescribedVelocity = prescribedVelocity
    }
}
