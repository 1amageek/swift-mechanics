
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct IndependentRuntimeWorldFactory<Checkpoints: RuntimeCheckpointHandling>: RuntimeWorldCreating, Sendable {
    public typealias Session = RuntimeSession<Checkpoints>
    public let checkpoints: Checkpoints
    public init(checkpoints: Checkpoints) { self.checkpoints = checkpoints }
    public func create(model: CompiledMechanicalModel, configuration: RuntimeConfiguration, initialState: KinematicState,
                       contributors: [RuntimeContributorState], rootSeed: UInt64, count: Int) throws(RuntimeFailure) -> [Session] {
        guard count >= 0, count <= configuration.capacity.maximumBatchStates else { throw RuntimeFailure(.capacityExceeded, message: "Requested world count exceeds batch capacity.") }
        var sessions: [Session] = []; sessions.reserveCapacity(count)
        for index in 0..<count {
            do throws(RuntimeFailure) {
                let session = try Session(model: model, configuration: configuration, initialState: initialState, contributors: contributors,
                    seed: RuntimeRandomState.worldSeed(rootSeed: rootSeed, index: UInt64(index)), checkpoints: checkpoints)
                sessions.append(session)
            } catch { throw RuntimeFailure(error.code, contributor: error.contributor, message: "World " + String(index) + " failed: " + error.message) }
        }
        return sessions
    }
}
