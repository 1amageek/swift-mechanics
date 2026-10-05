internal struct ControlMechanicalSample: Sendable {
    let system:RigidDynamicsSystem
    let acceleration:Double
    let kineticEnergy:Double
    let forceResidual:Double
}
