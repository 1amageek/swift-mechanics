/// Tentative immutable evidence; does not publish a Runtime accepted state or event token.
public struct FrictionalImpulseResult: Sendable {
    public let input: FrictionalImpulseInput
    public let stateAfter: KinematicState
    public let snapshotAfter: KinematicSnapshot
    public let physicalBefore: PhysicalRigidDynamicsSystem
    public let physicalAfter: PhysicalRigidDynamicsSystem
    public let regime: FrictionalImpulseRegime
    /// Components in the original ContactBasis, in N s.
    public let impulse: Vector3
    /// Components in the original ContactBasis, in m/s, including prescribed drift.
    public let relativeVelocityBefore: Vector3
    public let relativeVelocityAfter: Vector3
    public let firstImpulse: FramedImpulse
    public let secondImpulse: FramedImpulse
    /// Numerical body-origin impulse wrench, in N m s / N s, not a continuous force.
    public let firstOriginImpulse: SpatialWrench
    public let secondOriginImpulse: SpatialWrench
    public let energyBefore: MechanicalEnergy
    public let energyAfter: MechanicalEnergy
    public let diagnostics: FrictionalImpulseDiagnostics
}
