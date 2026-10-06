import Synchronization
@available(macOS 15.0, *)
internal final class ModalReductionCancellationCounter: Sendable {
    private let state = Mutex<Int>(0)
    let cancellationCheckpoint: Int?
    init(cancellationCheckpoint: Int? = nil) { self.cancellationCheckpoint = cancellationCheckpoint }
    func check() -> Bool {
        state.withLock { count in count += 1; return cancellationCheckpoint == count }
    }
    var checkpoints: Int { state.withLock { $0 } }
}
