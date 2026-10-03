import MechanicsCore

public struct JointKinematics: Equatable, Sendable {
    public let frameMotion: FrameMotion
    public let subspace: JointMotionSubspace
    public let coordinateRate: [Double]

    internal init(frameMotion: FrameMotion, subspace: JointMotionSubspace, coordinateRate: [Double]) {
        self.frameMotion = frameMotion
        self.subspace = subspace
        self.coordinateRate = coordinateRate
    }
}
