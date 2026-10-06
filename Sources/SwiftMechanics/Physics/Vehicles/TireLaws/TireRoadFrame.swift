/// Maps zero-camber x-forward/y-axle/z-road-normal axes to the reference frame.
public struct TireRoadFrame: Sendable {
    public let reference: ModelReference
    public let contactToReference: UnitQuaternion
    public let planePoint: Vector3

    public init(reference: ModelReference, contactToReference: UnitQuaternion,
                planePoint: Vector3) throws(TireLawError) {
        guard reference.id.kind == .frame else { throw .invalidInput }
        self.reference = reference; self.contactToReference = contactToReference
        self.planePoint = planePoint
    }
}
