public protocol RigidMaterialAttachmentComputing: Sendable {
    func materialSite(_ material: SurfaceMaterialPoint, snapshot: DeformingSurfaceSnapshot,
                      policy: AttachmentPolicy, surfacePolicy: DeformingContactPolicy,
                      work: inout NumericalWork) throws(AttachmentError) -> AttachmentMaterialSite
    func query(_ attachments: [RigidMaterialAttachment], boundaryOwner: String,
               existingBoundaryRows: [[Double]], rigid: AttachmentRigidSource,
               material: DeformingSurfaceSnapshot, policy: AttachmentPolicy,
               surfacePolicy: DeformingContactPolicy,
               work: inout NumericalWork) throws(AttachmentError) -> RigidMaterialAttachmentQuery
    func forces(_ query: RigidMaterialAttachmentQuery, multipliers: [Double],
                currentRigid: AttachmentRigidSource, currentMaterial: DeformingSurfaceSnapshot,
                policy: AttachmentPolicy, surfacePolicy: DeformingContactPolicy,
                work: inout NumericalWork) throws(AttachmentError) -> AttachmentForceProposal
}
