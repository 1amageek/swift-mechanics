internal final class NonlinearPhysicalSolveContext: Sendable {
    let system:PhysicalRigidDynamicsSystem
    let sample:VelocityConstraintSample
    let impulse:Bool
    let positionResidual:Double
    let velocityResidual:Double
    let prescribedRoot:PrescribedRootConstraint?
    init(system:PhysicalRigidDynamicsSystem,sample:VelocityConstraintSample,impulse:Bool,positionResidual:Double,velocityResidual:Double,
         prescribedRoot:PrescribedRootConstraint? = nil) {
        self.prescribedRoot=prescribedRoot
        self.system=system;self.sample=sample;self.impulse=impulse;self.positionResidual=positionResidual;self.velocityResidual=velocityResidual
    }
}
