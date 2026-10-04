import Synchronization

@available(macOS 15.0, *)
final class MachineCounter: Sendable {
    private let counts = Mutex((identities: 0, contents: 0, releases: 0))
    func identity() { counts.withLock { $0.identities += 1 } }
    func content() { counts.withLock { $0.contents += 1 } }
    func release() { counts.withLock { $0.releases += 1 } }
    var snapshot: (identities: Int, contents: Int, releases: Int) { counts.withLock { $0 } }
}
