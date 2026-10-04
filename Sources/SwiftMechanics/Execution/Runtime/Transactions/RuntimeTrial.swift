
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct RuntimeTrial: Sendable {
    private var q: [Double]
    private var v: [Double]
    private var acceleration: [Double]
    private var time: Double
    private var contributors: [RuntimeContributorState]
    private var random: RuntimeRandomState
    private let capacity: RuntimeCapacity
    private var binding: RuntimeCancellationSource?
    internal init(admission: _RuntimeTrialAdmission) throws(RuntimeFailure) {
        let accepted = admission.accepted, capacity = admission.capacity
        let state = accepted.physical.state
        let count = try RuntimeCounts.physical(q: state.q.count, v: state.v.count)
        guard count <= capacity.maximumPhysicalScalars else { throw RuntimeFailure(.capacityExceeded, message: "Physical trial scalar slots exceed capacity.") }
        q = state.q; v = state.v; acceleration = state.acceleration; time = state.time
        contributors = accepted.checkpoint.contributors; random = accepted.checkpoint.random; self.capacity = capacity; binding = nil
    }
    internal mutating func reset(admission: _RuntimeOperationAdmission) throws(RuntimeFailure) {
        let accepted = admission.accepted
        let state = accepted.physical.state
        guard q.count == state.q.count, v.count == state.v.count, acceleration.count == state.acceleration.count else { throw RuntimeFailure(.invalidOwnerAccess, message: "Reserved workspace layout changed.") }
        for i in q.indices { q[i] = state.q[i] }
        for i in v.indices { v[i] = state.v[i]; acceleration[i] = state.acceleration[i] }
        time = state.time; contributors = accepted.checkpoint.contributors; random = accepted.checkpoint.random; binding = admission.source
    }
    public var timeSeconds: Double { time }
    public func position(at index: Int) throws(RuntimeFailure) -> Double {
        guard q.indices.contains(index) else { throw RuntimeFailure(.invalidInput, message: "Position index is outside trial layout.") }; return q[index]
    }
    public func velocity(at index: Int) throws(RuntimeFailure) -> Double {
        guard v.indices.contains(index) else { throw RuntimeFailure(.invalidInput, message: "Velocity index is outside trial layout.") }; return v[index]
    }
    public mutating func setPosition(_ value: Double, at index: Int) throws(RuntimeFailure) {
        guard value.isFinite, q.indices.contains(index) else { throw RuntimeFailure(.invalidState, message: "Invalid trial position/index.") }; q[index] = value
    }
    public mutating func setVelocity(_ value: Double, at index: Int) throws(RuntimeFailure) {
        guard value.isFinite, v.indices.contains(index) else { throw RuntimeFailure(.invalidState, message: "Invalid trial velocity/index.") }; v[index] = value
    }
    public mutating func setAcceleration(_ value: Double, at index: Int) throws(RuntimeFailure) {
        guard value.isFinite, acceleration.indices.contains(index) else { throw RuntimeFailure(.invalidState, message: "Invalid trial acceleration/index.") }; acceleration[index] = value
    }
    public mutating func setTime(_ value: Double) throws(RuntimeFailure) {
        guard value.isFinite else { throw RuntimeFailure(.invalidState, message: "Trial time must be finite.") }; time = value
    }
    public func contributor(_ id: String) throws(RuntimeFailure) -> RuntimeContributorState {
        guard let record = contributors.first(where: { $0.id == id }) else { throw RuntimeFailure(.missingContributor, contributor: id, message: "Trial contributor is missing.") }; return record
    }
    public mutating func replaceContributor(_ record: RuntimeContributorState) throws(RuntimeFailure) {
        guard let index = contributors.firstIndex(where: { $0.id == record.id }) else { throw RuntimeFailure(.unknownContributor, contributor: record.id, message: "Trial cannot add undeclared contributor state.") }
        guard record.bytes.count <= capacity.maximumContributorBytes else { throw RuntimeFailure(.capacityExceeded, contributor: record.id, message: "Trial payload exceeds byte capacity.") }
        var bytes = record.bytes.count
        for (otherIndex, other) in contributors.enumerated() where otherIndex != index { bytes = try RuntimeCounts.sum(bytes, other.bytes.count) }
        guard bytes <= capacity.maximumContributorBytes else { throw RuntimeFailure(.capacityExceeded, contributor: record.id, message: "Total trial contributor bytes exceed capacity.") }
        contributors[index] = record
    }
    public mutating func nextRandom() throws(RuntimeFailure) -> UInt64 { try random.next() }
    internal func isBound(to source: RuntimeCancellationSource) -> Bool { binding === source }
    internal func checkpoint(from accepted: RuntimeAcceptedState) throws(RuntimeFailure) -> RuntimeCheckpoint {
        guard time >= accepted.physical.state.time else { throw RuntimeFailure(.invalidState, message: "Accepted trial time cannot move backwards.") }
        guard accepted.checkpoint.acceptedSteps < UInt64.max else { throw RuntimeFailure(.capacityExceeded, message: "Accepted sequence overflow.") }
        let physical: KinematicState
        do { physical = try KinematicState(revision: accepted.physical.stamp.revision, time: time, q: q, v: v, acceleration: acceleration) }
        catch { throw RuntimeFailure(.invalidState, message: "Trial physical state construction failed.") }
        return try RuntimeCheckpoint(model: accepted.physical.stamp, continuation: accepted.checkpoint.continuation,
            physical: physical, contributors: contributors, random: random, acceptedSteps: accepted.checkpoint.acceptedSteps + 1)
    }
}
