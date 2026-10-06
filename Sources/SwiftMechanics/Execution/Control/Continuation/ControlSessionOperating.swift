@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public protocol ControlSessionOperating: Sendable {
    func step(input:ControlSampleInput) throws(ControlFailure) -> ControlStepResult
    func observe(_ operation:@Sendable (ControlObservation) throws(ControlFailure) -> Void) throws(ControlFailure)
    func checkpoint(codec:any RuntimeCheckpointCoding) throws(ControlFailure) -> [UInt8]
    func restart(_ bytes:[UInt8],codec:any RuntimeCheckpointCoding) throws(ControlFailure)
    func cancel()
    func shutdown() -> RuntimeShutdownStatus
    func shutdownStatus() -> RuntimeShutdownStatus?
}
