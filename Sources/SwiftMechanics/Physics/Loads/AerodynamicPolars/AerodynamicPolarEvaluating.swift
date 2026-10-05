public protocol AerodynamicPolarEvaluating: Sendable {
    func evaluate(_ law: AerodynamicPolarLaw, density: Double, body: EntityID, frame: EntityID,
                  point: Vector3, chordAxis: Vector3, spanAxis: Vector3, velocity: Vector3,
                  mediumVelocity: Vector3, work: inout LoadWork) throws(LoadError) -> AerodynamicPolarResponse
}
