internal struct URDFDraft {
    let robotName: String
    let descriptor: MechanicalDescriptor
    let geometries: [URDFGeometryRecord]
    let collisions: [URDFCollisionBinding]
    let assets: [URDFAssetReference]
    let losses: [URDFLoss]
}
