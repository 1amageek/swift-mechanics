import Synchronization

@available(macOS 15.0, *)
final class AffineRigidGravityQualificationCancellation: Sendable {
    private let count = Mutex(0)
    private let cancelAt: Int
    init(cancelAt: Int) { self.cancelAt = cancelAt }
    func isCancelled() -> Bool {
        count.withLock { value in
            value += 1
            return value >= cancelAt
        }
    }
}
