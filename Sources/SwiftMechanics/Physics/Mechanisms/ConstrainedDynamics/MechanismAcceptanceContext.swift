/// Immutable retained inputs for original acceptance; array backing remains retained by its COW values.
internal final class MechanismAcceptanceContext: Sendable {
    let system:PhysicalRigidDynamicsSystem
    let sample:VelocityConstraintSample
    let base:[Double]
    let values:[Double]
    let drive:[Double]
    let multipliers:[Double]
    let reaction:[Double]
    let rank:ConstraintRankEvidence
    let impulse:Bool
    let policy:MechanismSolvePolicy
    let count:Int
    let timeScale:Double
    let energyScale:Double
    let scales:[Double]
    let prescribedRoot:PrescribedRootConstraint?
    init(system:PhysicalRigidDynamicsSystem,sample:VelocityConstraintSample,base:[Double],values:[Double],drive:[Double],
         multipliers:[Double],reaction:[Double],rank:ConstraintRankEvidence,impulse:Bool,policy:MechanismSolvePolicy,
         prescribedRoot:PrescribedRootConstraint? = nil) {
        self.prescribedRoot=prescribedRoot
        self.system=system;self.sample=sample;self.base=base;self.values=values;self.drive=drive
        self.multipliers=multipliers;self.reaction=reaction;self.rank=rank;self.impulse=impulse;self.policy=policy
        count=system.velocityCount;timeScale=sample.layout.timeScale;energyScale=policy.dynamics.energyScale;scales=sample.layout.scales
    }
}
