import Synchronization
import MechanicsRuntime

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class RuntimeStoredTicket: Sendable {
    private let stored = Mutex<(RuntimeTrial?, RuntimeStepControl?)>((nil,nil))
    func save(_ trial: RuntimeTrial, _ control: RuntimeStepControl) { stored.withLock { $0 = (trial,control) } }
    func load() -> (RuntimeTrial?, RuntimeStepControl?) { stored.withLock { $0 } }
}
