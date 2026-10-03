import MechanicsCore
import MechanicsModel
public struct NodalState: Sendable {
    public let frame: EntityID
    public let meshRevision: UInt64
    public let nodeIdentifiers: [UInt64]
    public let positions: [Vector3]
    public let velocities: [Vector3]
    public init(frame: EntityID, meshRevision: UInt64, nodeIdentifiers: [UInt64], positions: [Vector3], velocities: [Vector3]) {
        self.frame = frame; self.meshRevision = meshRevision; self.nodeIdentifiers = nodeIdentifiers; self.positions = positions; self.velocities = velocities
    }
}
