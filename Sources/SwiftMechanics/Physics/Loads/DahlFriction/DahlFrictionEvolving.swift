public protocol DahlFrictionEvolving: Sendable {
    func step(law: DahlFrictionLaw, accepted: DahlFrictionState, speed: Double,
              timeStep: Double, work: inout LoadWork) throws(LoadError) -> DahlFrictionResponse
}
