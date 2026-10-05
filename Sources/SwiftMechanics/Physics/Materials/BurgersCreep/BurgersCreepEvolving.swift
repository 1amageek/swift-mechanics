public protocol BurgersCreepEvolving: Sendable {
    func step(law: BurgersCreepLaw, accepted: BurgersCreepState, appliedStress: Double,
              timeStep: Double) throws(MaterialError) -> BurgersCreepResponse
}
