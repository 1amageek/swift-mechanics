public protocol CapstanFrictionEvaluating: Sendable {
    func sticking(law: CapstanFrictionLaw, upstreamTension: Double, downstreamTension: Double,
                  work: inout ActuationWork) throws(ActuationError) -> CapstanResponse
    func sliding(law: CapstanFrictionLaw, lowTension: Double, slipSpeed: Double,
                 work: inout ActuationWork) throws(ActuationError) -> CapstanResponse
}
