import MechanicsCollision

internal final class HardImpactRowGeometry: Sendable {
    let assembly: HardImpactAssembly
    let contact: ImpulseContactBinding
    let first: CollisionProxy
    let second: CollisionProxy
    init(assembly: HardImpactAssembly, contact: ImpulseContactBinding, first: CollisionProxy, second: CollisionProxy) { self.assembly=assembly; self.contact=contact; self.first=first; self.second=second }
}
