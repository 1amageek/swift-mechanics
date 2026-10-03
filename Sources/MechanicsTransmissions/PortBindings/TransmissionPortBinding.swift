import MechanicsCore
import MechanicsModel
import MechanicsJoints

public struct TransmissionPortBinding: Sendable {
    public let coordinateIndex: Int
    public let coordinateID: UInt64
    public let body: EntityID
    public let joint: EntityID
    public let frame: EntityID
    public let manifold: JointManifold
    public let jointToReference: RigidTransform
    public let layoutRevision: UInt64
    public let modelRevision: UInt64
    public init(coordinateIndex: Int, coordinateID: UInt64, body: EntityID, joint: EntityID, frame: EntityID, manifold: JointManifold,
                jointToReference: RigidTransform, layoutRevision: UInt64, modelRevision: UInt64) throws(TransmissionError) {
        guard coordinateIndex >= 0, body.kind == .body, joint.kind == .joint, frame.kind == .frame else { throw .invalidInput }
        self.coordinateIndex=coordinateIndex; self.coordinateID=coordinateID; self.body=body; self.joint=joint; self.frame=frame
        self.manifold=manifold; self.jointToReference=jointToReference; self.layoutRevision=layoutRevision; self.modelRevision=modelRevision
    }
}
