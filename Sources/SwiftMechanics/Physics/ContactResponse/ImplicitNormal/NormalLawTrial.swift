
internal struct NormalLawTrial: Sendable {
    let force: Double
    let relative: Vector3
    let normalVelocity: Double
    let gap: Double
    let x: Double
    let response: ContactResponse
    let lawResidual: Double
    let coneResidual: Double
}
