import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,visionOS 2.0,*)
internal final class PlanarReactionCancellationFlag: Sendable {
    private let storage=Mutex(false)
    var cancelled: Bool { storage.withLock {$0} }
    func cancel() { storage.withLock {$0=true} }
}
