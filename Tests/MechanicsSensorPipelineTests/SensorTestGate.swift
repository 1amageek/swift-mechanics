import SwiftMechanics
import Synchronization
import Foundation

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class SensorTestGate: Sendable {
    private struct State: Sendable { var entered = false; var open = false }
    private let storage = Mutex(State())
    private let notification = NSCondition()
    // The existing one-minute suite budget also bounds this Native test barrier.
    private static let timeoutSeconds = 60.0

    func wait() throws(SensorPipelineFailure) {
        notification.lock()
        defer { notification.unlock() }
        storage.withLock { $0.entered = true }
        notification.broadcast()
        let deadline = Date(timeIntervalSinceNow: Self.timeoutSeconds)
        // Both the predicate check and its opener take notification before storage,
        // so opening cannot race between this check and the atomic condition wait.
        while !storage.withLock({ $0.open }) {
            if !notification.wait(until: deadline), !storage.withLock({ $0.open }) {
                throw .busy
            }
        }
    }

    private func requireEntry() throws(SensorPipelineFailure) {
        notification.lock()
        defer { notification.unlock() }
        let deadline = Date(timeIntervalSinceNow: Self.timeoutSeconds)
        while !storage.withLock({ $0.entered }) {
            guard !storage.withLock({ $0.open }), notification.wait(until: deadline) else {
                if storage.withLock({ $0.entered }) { return }
                throw .busy
            }
        }
    }

    func waitForEntry() async throws(SensorPipelineFailure) {
        try requireEntry()
    }

    func open() {
        notification.lock()
        storage.withLock { $0.open = true }
        notification.broadcast()
        notification.unlock()
    }
}
