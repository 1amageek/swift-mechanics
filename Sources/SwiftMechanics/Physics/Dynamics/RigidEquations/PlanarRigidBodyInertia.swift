/// Original planar mass, body-local COM and polar inertia; no transverse moments are inferred.
public struct PlanarRigidBodyInertia: Equatable, Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let properties: MassProperties2D
    public init(body: EntityID, frame: EntityID, properties: MassProperties2D) throws(DynamicsError) {
        guard body.kind == .body, frame.kind == .frame else { throw .invalidInput }
        self.body = body; self.frame = frame; self.properties = properties
    }
}
