public protocol MaxwellEvolving: Sendable {
    func step(law: MaxwellLaw, accepted: MaxwellState, strainRate: Double, timeStep: Double) throws(MaterialError) -> MaxwellResponse
}
