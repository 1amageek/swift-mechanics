@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol CoSimulationCreating: Sendable {
    func make(first: CoSimulationParticipantConfiguration, second: CoSimulationParticipantConfiguration,
              coupling: CoSimulationCoupling, budget: CoSimulationBudget) throws(CoSimulationFailure) -> any CoSimulationOperating
}
