import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class CoSimulationQualificationGate: Sendable {
    public enum Mode: Sendable { case idle, cancel, reentry }
    private struct State: Sendable {
        var mode: Mode = .idle
        var owner: (any CoSimulationOperating)?
        var reentries = 0
        var invalidReentry = false
    }
    private let state = Mutex(State())
    public init() {}
    public func install(_ owner: any CoSimulationOperating) {
        let retired = state.withLock { value in
            let old = value.owner; value.owner = owner; return old
        }
        withExtendedLifetime(retired) {}
    }
    public func arm(_ mode: Mode) { state.withLock { $0.mode = mode } }
    public func clear() {
        let retired = state.withLock { value in
            let old = value.owner; value.owner = nil; value.mode = .idle; return old
        }
        withExtendedLifetime(retired) {}
    }
    public func poll() -> Bool {
        let checked = state.withLock { ($0.mode, $0.owner) }
        switch checked.0 {
        case .idle: return false
        case .cancel: return true
        case .reentry:
            guard let owner = checked.1 else { return false }
            var invalid = false
            do { _ = try owner.snapshot(); invalid = true }
            catch { if case .busy = error.cause {} else { invalid = true } }
            state.withLock { $0.reentries += 1; $0.invalidReentry = $0.invalidReentry || invalid }
            return false
        }
    }
    public var validReentryCount: Int { state.withLock { $0.invalidReentry ? -1 : $0.reentries } }
}
