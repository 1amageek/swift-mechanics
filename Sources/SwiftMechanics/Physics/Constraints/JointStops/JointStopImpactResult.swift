/// Tentative instantaneous jump evidence, not an accepted Runtime state or a body reaction.
public struct JointStopImpactResult: Sendable {
    public let prepared: PreparedJointStop
    public let side: JointStopSide
    public let stateAfter: CompiledKinematicState
    public let sourceAfter: ObservationSource
    public let encoderAfter: JointEncoderObservation
    public let physicalBefore: PhysicalRigidDynamicsSystem
    public let physicalAfter: PhysicalRigidDynamicsSystem
    public let energyBefore: MechanicalEnergy
    public let energyAfter: MechanicalEnergy
    public let velocityJump: [Double]
    public let generalizedImpulse: [Double]
    public let normalImpulseNewtonSeconds: Double
    /// Positive conjugate multiplier: N m s/rad for rotary or N s for prismatic.
    public let coordinateImpulse: Double
    public let coordinateImpulseUnit: PhysicalDimension
    public let diagnostics: JointStopDiagnostics
}
