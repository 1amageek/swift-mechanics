@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol CoSimulationOperating: Sendable {
    func snapshot() throws(CoSimulationFailure) -> CoSimulationBoundary
    func step(expectedTick: UInt64, expectedTimeSeconds: Double) throws(CoSimulationFailure) -> CoSimulationMacroReceipt
    func status() -> CoSimulationStatus
    func shutdown() -> RuntimeShutdownStatus
}
