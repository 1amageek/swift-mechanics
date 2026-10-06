@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal protocol CoSimulationPhysicalParticipant: Sendable {
    var configuration: CoSimulationParticipantConfiguration { get }
    func observe() throws(CoSimulationFailure) -> ControlObservation
    func checkpoint() throws(CoSimulationFailure) -> [UInt8]
    func verifyCheckpoint(_ bytes: [UInt8], expected: ControlObservation) throws(CoSimulationFailure)
    func advance(from: ControlObservation, effort: Double, work: inout NumericalWork) throws(CoSimulationFailure) -> ControlStepResult
    func restart(_ bytes: [UInt8]) throws(CoSimulationFailure)
    func shutdown() -> RuntimeShutdownStatus
}
