import MechanicsModel
public struct RigidBodyInertia: Equatable, Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let properties: MassProperties3D
    public init(body: EntityID, frame: EntityID, properties: MassProperties3D) throws(DynamicsError) {
        guard body.kind == .body, frame.kind == .frame else { throw .invalidInput }
        self.body = body; self.frame = frame; self.properties = properties
    }
}
