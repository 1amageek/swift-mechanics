import SwiftMechanics
import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
final class ControlTestCapture: Sendable {
    private let value=Mutex<ControlObservation?>(nil)
    func store(_ observation:ControlObservation) { value.withLock { $0=observation } }
    func read() -> ControlObservation? { value.withLock { $0 } }
}
