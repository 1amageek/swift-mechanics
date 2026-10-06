public struct RigidMaterialAttachment: Sendable {
    public let identifier: String
    public let boundaryOwner: String
    public let rigidBody: EntityID
    public let rigidFrame: EntityID
    public let rigidRevision: UInt64
    public let bodyLocalPoint: Vector3
    public let site: AttachmentMaterialSite
    public let degreesOfFreedom: AttachmentDegreesOfFreedom

    public init(identifier: String, boundaryOwner: String, rigidBody: EntityID, rigidFrame: EntityID,
                rigidRevision: UInt64, bodyLocalPoint: Vector3, site: AttachmentMaterialSite,
                degreesOfFreedom: AttachmentDegreesOfFreedom) throws(AttachmentError) {
        guard !identifier.isEmpty, !boundaryOwner.isEmpty, rigidBody.kind == .body,
              rigidFrame.kind == .frame else { throw .invalidInput }
        self.identifier = identifier; self.boundaryOwner = boundaryOwner
        self.rigidBody = rigidBody; self.rigidFrame = rigidFrame; self.rigidRevision = rigidRevision
        self.bodyLocalPoint = bodyLocalPoint; self.site = site; self.degreesOfFreedom = degreesOfFreedom
    }
}
