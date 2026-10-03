import MechanicsJoints

public struct CompiledKinematicState: Equatable, Sendable {
    public let stamp: ModelStamp
    public let state: KinematicState

    internal init(stamp: ModelStamp, state: KinematicState) { self.stamp = stamp; self.state = state }
}
