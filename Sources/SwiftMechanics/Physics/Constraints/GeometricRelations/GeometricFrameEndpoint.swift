/// A point/direction expressed in a named fixed frame attached to the identified body.
public struct GeometricFrameEndpoint: Equatable, Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let point: Vector3
    public let axis: Vector3
    public init(body: EntityID, frame: EntityID, point: Vector3 = .zero, axis: Vector3 = .unitZ) throws(GeometricConstraintError) {
        guard body.kind == .body, frame.kind == .frame, axis != .zero else { throw .invalidInput }
        self.body=body;self.frame=frame;self.point=point
        self.axis=try GeometricArithmetic.geometry { try axis.normalized() }
    }
}
