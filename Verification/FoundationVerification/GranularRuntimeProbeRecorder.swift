import SwiftMechanics
import Synchronization

/// Retains one actual public trial report across the Sendable Runtime callback.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class GranularRuntimeProbeRecorder: Sendable {
    private let storage = Mutex<GranularStepResult?>(nil)

    func record(_ report: GranularStepResult) {
        let retired = storage.withLock { value in
            let previous = value
            value = report
            return previous
        }
        withExtendedLifetime(retired) {}
    }

    func report() -> GranularStepResult? { storage.withLock { $0 } }
}
