public protocol StandardLinearSolidEvolving: Sendable {
    func step(law: StandardLinearSolidLaw, accepted: StandardLinearSolidState, strainRate: Double,
              timeStep: Double) throws(MaterialError) -> StandardLinearSolidResponse
}
