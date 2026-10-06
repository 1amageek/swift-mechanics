public protocol HarmonicGravityEvaluating: Sendable {
    func evaluate(_ law: HarmonicGravityLaw, body: EntityID, sample: GravitySample, velocity: Vector3,
                  time: Double, work: inout LoadWork) throws(LoadError) -> HarmonicGravityResponse
}
