public struct RigidDynamicsInput: Sendable {
    public let snapshot: KinematicSnapshot
    public let velocity: [Double]
    public let inertias: [RigidBodyInertia]
    public let gravity: AffineGravity?
    public let bodyWrenches: [BodyWrenchContribution]
    public let generalizedForces: [GeneralizedForceContribution]
    public init(snapshot: KinematicSnapshot, velocity: [Double], inertias: [RigidBodyInertia],
                gravity: AffineGravity?, bodyWrenches: [BodyWrenchContribution] = [],
                generalizedForces: [GeneralizedForceContribution] = []) throws(DynamicsError) {
        guard velocity.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        self.snapshot = snapshot; self.velocity = velocity; self.inertias = inertias; self.gravity = gravity
        self.bodyWrenches = bodyWrenches; self.generalizedForces = generalizedForces
    }
}
