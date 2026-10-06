internal struct CableTrial {
    let state: NodalState
    let mechanicalEnergy: Double
    let externalWork: Double
    let dampingWorkLoss: Double
    let energyResidual: Double
    let momentumResidual: Double
    let angularMomentumResidual: Double
    let appliedImpulse: Vector3
    let appliedAngularImpulse: Vector3
    let supportImpulse: [Vector3]
}
