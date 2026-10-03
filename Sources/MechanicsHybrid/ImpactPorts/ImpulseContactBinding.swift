import MechanicsCore
import MechanicsCollision
import MechanicsContactLaws

public struct ImpulseContactBinding: Sendable {
    public let eventID: UInt64
    public let witness: CollisionWitness
    public let firstProxyIndex: Int
    public let secondProxyIndex: Int
    public let firstColliderToBody: RigidTransform
    public let secondColliderToBody: RigidTransform
    public let law: ContactLawPair
    public init(eventID: UInt64, witness: CollisionWitness, firstProxyIndex: Int, secondProxyIndex: Int,
                firstColliderToBody: RigidTransform, secondColliderToBody: RigidTransform, law: ContactLawPair) {
        self.eventID=eventID; self.witness=witness; self.firstProxyIndex=firstProxyIndex; self.secondProxyIndex=secondProxyIndex
        self.firstColliderToBody=firstColliderToBody; self.secondColliderToBody=secondColliderToBody; self.law=law
    }
}
