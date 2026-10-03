import MechanicsCompiler
import MechanicsJoints

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct RuntimeSessionMetadata: Sendable {
    let model: CompiledMechanicalModel
    var accepted: RuntimeAcceptedState
    var workspace: RuntimeTrial?
    var activeTicket: UInt64?
    var activeSource: RuntimeCancellationSource?
    var cancelRequested = false
    var closing = false
    var closed = false
    var observers = 0
    var attempted: UInt64 = 0
    var committed: UInt64 = 0
    var rejected: UInt64 = 0
    var failed: UInt64 = 0
    var releaseIssued = false
    let scalarSlots: Int
    init(model: CompiledMechanicalModel, accepted: RuntimeAcceptedState, capacity: RuntimeCapacity) throws(RuntimeFailure) {
        self.model = model; self.accepted = accepted; self.workspace = try RuntimeTrial(accepted: accepted, capacity: capacity)
        scalarSlots = try RuntimeCounts.physical(q: accepted.physical.state.q.count, v: accepted.physical.state.v.count)
    }
}
