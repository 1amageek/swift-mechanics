import MechanicsDynamics

internal final class HardImpactAssembly: Sendable {
    let source: HardImpactSnapshot
    let system: RigidDynamicsSystem
    let contacts: [ImpulseContactBinding]
    let rowCount: Int
    let velocityCount: Int
    init(source: HardImpactSnapshot, system: RigidDynamicsSystem, contacts: [ImpulseContactBinding], rowCount: Int, velocityCount: Int) { self.source=source; self.system=system; self.contacts=contacts; self.rowCount=rowCount; self.velocityCount=velocityCount }
}
