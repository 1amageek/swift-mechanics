public protocol CableEvolving: Sendable {
    func evolve(_ cable: DiscreteCable, state: NodalState, loads: CableLoads, duration: Double,
                policy: CablePolicy, work: inout NumericalWork) -> CableEvolutionResult
}
