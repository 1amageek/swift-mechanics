/// Small immutable per-body original properties cross the source-extraction boundary.
internal struct RigidBodyPhysicalProperties: Sendable {
    let mass:Double
    let center:Vector3
    let inertia:RigidInertiaAction
}
