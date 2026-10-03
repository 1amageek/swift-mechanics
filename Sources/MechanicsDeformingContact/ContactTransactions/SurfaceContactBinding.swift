import MechanicsCollision
import MechanicsContactLaws
public struct SurfaceContactBinding: Sendable {
    public let key: String
    public let witness: SurfaceContactWitness
    public let pair: ContactLawPair
    public let currentObstacle: CollisionProxy?
    public init(key: String, witness: SurfaceContactWitness, pair: ContactLawPair, currentObstacle: CollisionProxy?) {
        self.key=key; self.witness=witness; self.pair=pair; self.currentObstacle=currentObstacle
    }
}
