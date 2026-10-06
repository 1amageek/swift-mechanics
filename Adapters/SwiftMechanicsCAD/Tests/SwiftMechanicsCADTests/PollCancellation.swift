import Synchronization

@available(macOS 15, *)
final class PollCancellation: Sendable {
    private let count = Mutex(0)
    private let successfulPolls: Int

    init(successfulPolls: Int) { self.successfulPolls = successfulPolls }

    func cancelled() -> Bool {
        count.withLock { value in
            value += 1
            return value > successfulPolls
        }
    }
}
