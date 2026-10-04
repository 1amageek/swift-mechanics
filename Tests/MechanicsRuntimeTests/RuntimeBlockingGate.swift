import SwiftMechanics
import Foundation
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class RuntimeBlockingGate: Sendable {
    private struct State: Sendable { var entered = false; var open = false }
    private let state = Mutex(State())
    func wait() throws(RuntimeFailure) {
        state.withLock { $0.entered = true }
        let clock = ContinuousClock(), deadline = clock.now.advanced(by: .seconds(3))
        while !state.withLock({ $0.open }) {
            guard clock.now < deadline else { throw RuntimeFailure(.invalidInput, message: "Fixture gate deadline exceeded.") }
            Thread.sleep(forTimeInterval: 0.001)
        }
    }
    func waitForEntry() async throws(RuntimeFailure) {
        let clock = ContinuousClock(), deadline = clock.now.advanced(by: .seconds(3))
        while !state.withLock({ $0.entered }) {
            guard clock.now < deadline else { throw RuntimeFailure(.invalidInput, message: "Fixture entry deadline exceeded.") }
            await Task.yield()
        }
    }
    func open() { state.withLock { $0.open = true } }
}
