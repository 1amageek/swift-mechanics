import MechanicsModel
public struct ContactIdentity: Equatable, Sendable {
    public let key: String
    public let firstBody: ModelReference
    public let secondBody: ModelReference
    public let frame: ModelReference
    public let firstGeometryRevision: UInt64
    public let secondGeometryRevision: UInt64
    public let tangentLayoutRevision: UInt64
    public init(key: String, firstBody: ModelReference, secondBody: ModelReference, frame: ModelReference,
                firstGeometryRevision: UInt64, secondGeometryRevision: UInt64, tangentLayoutRevision: UInt64) throws(ContactLawError) {
        guard !key.isEmpty, firstBody.id.kind == .body, secondBody.id.kind == .body,
              firstBody.id != secondBody.id, frame.id.kind == .frame else { throw .invalidIdentity }
        self.key=key; self.firstBody=firstBody; self.secondBody=secondBody; self.frame=frame
        self.firstGeometryRevision=firstGeometryRevision; self.secondGeometryRevision=secondGeometryRevision
        self.tangentLayoutRevision=tangentLayoutRevision
    }
}
