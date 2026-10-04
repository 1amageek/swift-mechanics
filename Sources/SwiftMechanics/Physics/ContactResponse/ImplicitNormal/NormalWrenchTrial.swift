
internal struct NormalWrenchTrial: Sendable {
    let forceA: Vector3
    let forceB: Vector3
    let torqueA: Vector3
    let torqueB: Vector3
    let lawResidual: Double
    let wrenchResidual: Double
}
