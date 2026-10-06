public struct CableLoads: Sendable {
    public let frame: EntityID
    public let revision: UInt64
    public let nodeIdentifiers: [UInt64]
    public let heldNodalForces: [Vector3]
    public let heldGravity: Vector3
    public let fixedNodes: [Bool]
    public init(frame: EntityID, revision: UInt64, nodeIdentifiers: [UInt64], heldNodalForces: [Vector3],
                heldGravity: Vector3, fixedNodes: [Bool]) {
        self.frame = frame; self.revision = revision; self.nodeIdentifiers = nodeIdentifiers
        self.heldNodalForces = heldNodalForces; self.heldGravity = heldGravity; self.fixedNodes = fixedNodes
    }
}
