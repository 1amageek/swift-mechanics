internal final class SleepImpactIncoming:Sendable {
    let snapshot:KinematicSnapshot
    let system:RigidDynamicsSystem
    init(snapshot:KinematicSnapshot,system:RigidDynamicsSystem) { self.snapshot=snapshot;self.system=system }
}
