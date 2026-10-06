internal final class GearedStrikerWitness: Sendable {
    let witness:CollisionWitness
    let first:CollisionProxy
    let second:CollisionProxy
    let speed:Double
    init(witness:CollisionWitness,first:CollisionProxy,second:CollisionProxy,speed:Double) { self.witness=witness;self.first=first;self.second=second;self.speed=speed }
}
