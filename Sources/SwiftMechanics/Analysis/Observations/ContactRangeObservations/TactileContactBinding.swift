/// The caller designates the issued history as accepted in this explicit material-axis layout.
public struct TactileContactBinding: Sendable {
    public let firstCollider: EntityID
    public let secondCollider: EntityID
    public let pair: ContactLawPair
    public let accepted: ContactHistory
    public let tangentLayoutRevision: UInt64
    public let firstMaterialTangentInCollider: Vector3
    public init(firstCollider: EntityID, secondCollider: EntityID, pair: ContactLawPair, accepted: ContactHistory,
                tangentLayoutRevision: UInt64, firstMaterialTangentInCollider: Vector3) throws(ContactRangeObservationError) {
        guard firstCollider.kind == .collider,secondCollider.kind == .collider,firstCollider != secondCollider,
              firstMaterialTangentInCollider != .zero else { throw .invalidInput }
        self.firstCollider=firstCollider;self.secondCollider=secondCollider;self.pair=pair;self.accepted=accepted
        self.tangentLayoutRevision=tangentLayoutRevision;self.firstMaterialTangentInCollider=firstMaterialTangentInCollider
    }
}
