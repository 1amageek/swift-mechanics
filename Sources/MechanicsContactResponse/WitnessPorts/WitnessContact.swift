import MechanicsCore
import MechanicsCollision
import MechanicsContactLaws
public struct WitnessContact: Sendable {
    public let coordinateID: UInt64
    public let tangentLayoutRevision: UInt64
    public let witness: CollisionWitness
    public let firstProxyIndex: Int
    public let secondProxyIndex: Int
    public let firstColliderToBody: RigidTransform
    public let secondColliderToBody: RigidTransform
    public let basis: ContactBasis
    public let pair: ContactLawPair
    public let accepted: ContactHistory
    public init(coordinateID: UInt64, tangentLayoutRevision: UInt64, witness: CollisionWitness, firstProxyIndex: Int, secondProxyIndex: Int,
                firstColliderToBody: RigidTransform, secondColliderToBody: RigidTransform,
                basis: ContactBasis, pair: ContactLawPair, accepted: ContactHistory) {
        self.coordinateID=coordinateID; self.tangentLayoutRevision=tangentLayoutRevision; self.witness=witness; self.firstProxyIndex=firstProxyIndex; self.secondProxyIndex=secondProxyIndex
        self.firstColliderToBody=firstColliderToBody; self.secondColliderToBody=secondColliderToBody
        self.basis=basis; self.pair=pair; self.accepted=accepted
    }
}
