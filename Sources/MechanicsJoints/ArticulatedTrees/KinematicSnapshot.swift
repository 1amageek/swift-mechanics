import MechanicsCore
import MechanicsModel

public struct KinematicSnapshot: Sendable {
    public let tree: KinematicTree
    public let time: Double
    public let bodies: [BodyKinematics]
    public let coordinateRate: [Double]
    public let joints: [JointFrameKinematics]
    public let frames: [FrameKinematics]
    private let frameIndices: [EntityID: Int]
    private let columns: [SpatialMotion]

    internal init(tree: KinematicTree, time: Double, bodies: [BodyKinematics], coordinateRate: [Double], columns: [SpatialMotion], joints: [JointFrameKinematics], frames: [FrameKinematics]) {
        self.tree = tree; self.time = time; self.bodies = bodies
        self.coordinateRate = coordinateRate; self.columns = columns
        self.joints = joints; self.frames = frames
        self.frameIndices = Dictionary(uniqueKeysWithValues: frames.enumerated().map { ($1.frame, $0) })
    }

    public func body(_ id: EntityID) throws(JointError) -> BodyKinematics { bodies[try tree.bodyIndex(id)] }

    public func frame(_ id: EntityID) throws(JointError) -> FrameKinematics {
        guard let index = frameIndices[id] else { throw .unknownFrame(id) }
        return frames[index]
    }

    /// The returned slice retains immutable owned array backing for its entire lifetime.
    public func geometricColumns(body id: EntityID) throws(JointError) -> ArraySlice<SpatialMotion> {
        let index = try tree.bodyIndex(id), count = tree.layout.velocityCount
        return columns[(index * count)..<((index + 1) * count)]
    }
}
