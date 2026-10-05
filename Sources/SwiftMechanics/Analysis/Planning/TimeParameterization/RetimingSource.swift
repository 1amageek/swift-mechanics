public struct RetimingSource: Sendable {
    public let sourceID: String
    public let tree: KinematicTree
    public let inertias: [RigidBodyInertia]
    public let gravity: AffineGravity?
    /// Constant external applied forces held in the tree's generalized coordinate basis.
    public let heldAppliedForces: [Double]
    public init(sourceID: String, tree: KinematicTree, inertias: [RigidBodyInertia],
                gravity: AffineGravity?, heldAppliedForces: [Double]) throws(RetimingError) {
        guard !sourceID.isEmpty, heldAppliedForces.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        self.sourceID = sourceID; self.tree = tree; self.inertias = inertias
        self.gravity = gravity; self.heldAppliedForces = heldAppliedForces
    }
}
