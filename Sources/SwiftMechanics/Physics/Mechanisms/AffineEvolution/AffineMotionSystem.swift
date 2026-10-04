internal final class AffineMotionSystem:Sendable {
    let value:RigidDynamicsSystem
    let reserved:Int
    init(_ value:RigidDynamicsSystem,reserved:Int) { self.value=value;self.reserved=reserved }
}
