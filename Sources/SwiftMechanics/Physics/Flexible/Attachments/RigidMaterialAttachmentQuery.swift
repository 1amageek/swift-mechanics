public final class RigidMaterialAttachmentQuery: Sendable {
    public let boundaryOwner: String
    public let attachments: [RigidMaterialAttachment]
    public let rigidSource: AttachmentRigidSource
    public let materialSnapshot: DeformingSurfaceSnapshot
    public let rows: [AttachmentConstraintRow]
    public let existingBoundaryRows: [[Double]]
    public let rigidVelocityCount: Int
    public let policy: AttachmentPolicy
    public let surfacePolicy: DeformingContactPolicy
    public let numericalWork: NumericalWork

    internal init(boundaryOwner: String, attachments: [RigidMaterialAttachment], rigid: AttachmentRigidSource,
                  material: DeformingSurfaceSnapshot, rows: [AttachmentConstraintRow], existing: [[Double]],
                  policy: AttachmentPolicy, surfacePolicy: DeformingContactPolicy, work: NumericalWork) {
        self.boundaryOwner = boundaryOwner; self.attachments = attachments; self.rigidSource = rigid
        self.materialSnapshot = material; self.rows = rows; self.existingBoundaryRows = existing
        self.rigidVelocityCount = rigid.snapshot.tree.layout.velocityCount; self.numericalWork = work
        self.policy = policy; self.surfacePolicy = surfacePolicy
    }
}
