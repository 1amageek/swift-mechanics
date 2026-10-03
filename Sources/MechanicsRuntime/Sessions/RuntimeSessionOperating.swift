@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol RuntimeSessionOperating: Sendable {
    func snapshot() -> RuntimeAcceptedState
    func profile() -> RuntimeProfile
    func performTrial(_ operation: @Sendable (inout RuntimeTrial, inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision) throws(RuntimeFailure) -> RuntimeTrialOutcome
    func observe(_ operation: @Sendable (RuntimeAcceptedState) throws(RuntimeFailure) -> Void) throws(RuntimeFailure)
    func restart(_ bytes: [UInt8], codec: any RuntimeCheckpointCoding) throws(RuntimeFailure) -> RuntimeAcceptedState
    func checkpoint(codec: any RuntimeCheckpointCoding) throws(RuntimeFailure) -> [UInt8]
    func cancel()
    func shutdown() -> RuntimeShutdownStatus
    func shutdownStatus() -> RuntimeShutdownStatus?
}
