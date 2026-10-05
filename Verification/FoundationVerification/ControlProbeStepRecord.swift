import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class ControlProbeStepRecord: Sendable {
    let result: ControlStepResult

    init(_ result: ControlStepResult) {
        self.result = result
    }
}
