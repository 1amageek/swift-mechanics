/// Complete original XY rigid-body source. Physical admission belongs to the equation kernel.
public struct PlanarRigidDynamicsInput: Sendable {
    public let snapshot: KinematicSnapshot
    public let velocity: [Double]
    public let inertias: [PlanarRigidBodyInertia]
    public let gravity: AffineGravity?
    public let bodyWrenches: [BodyWrenchContribution]
    public let generalizedForces: [GeneralizedForceContribution]
    public init(snapshot: KinematicSnapshot, velocity: [Double], inertias: [PlanarRigidBodyInertia],
                gravity: AffineGravity?, bodyWrenches: [BodyWrenchContribution] = [],
                generalizedForces: [GeneralizedForceContribution] = []) throws(DynamicsError) {
        guard velocity.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        self.snapshot = snapshot; self.velocity = velocity; self.inertias = inertias; self.gravity = gravity
        self.bodyWrenches = bodyWrenches; self.generalizedForces = generalizedForces
    }
}
