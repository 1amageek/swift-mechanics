import SwiftMechanics
import Synchronization
import Foundation

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class SensorTestGate: Sendable {
    private struct State: Sendable { var entered = false; var open = false }
    private let storage = Mutex(State())
    func wait() throws(SensorPipelineFailure) {
        storage.withLock { $0.entered = true }
        let clock = ContinuousClock(), deadline = clock.now.advanced(by: .seconds(3))
        while !storage.withLock({ $0.open }) {
            guard clock.now < deadline else { throw .busy }; Thread.sleep(forTimeInterval: 0.001)
        }
    }
    func waitForEntry() async throws(SensorPipelineFailure) {
        let clock = ContinuousClock(), deadline = clock.now.advanced(by: .seconds(3))
        while !storage.withLock({ $0.entered }) { guard clock.now < deadline else { throw .busy }; await Task.yield() }
    }
    func open() { storage.withLock { $0.open = true } }
}
