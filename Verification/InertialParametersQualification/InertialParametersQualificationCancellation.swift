import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class InertialParametersQualificationCancellation: Sendable {
    private let calls = Mutex(0)
    public let cancelAt: Int
    public init(cancelAt: Int) { self.cancelAt = cancelAt }
    public var count: Int { calls.withLock { $0 } }
    public func poll() -> Bool { calls.withLock { value in value += 1; return value >= cancelAt } }
}
