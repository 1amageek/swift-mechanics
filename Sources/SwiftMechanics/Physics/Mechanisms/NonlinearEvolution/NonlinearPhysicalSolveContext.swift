internal final class NonlinearPhysicalSolveContext: Sendable {
    let system:PhysicalRigidDynamicsSystem
    let sample:VelocityConstraintSample
    let impulse:Bool
    let positionResidual:Double
    let velocityResidual:Double
    init(system:PhysicalRigidDynamicsSystem,sample:VelocityConstraintSample,impulse:Bool,positionResidual:Double,velocityResidual:Double) {
        self.system=system;self.sample=sample;self.impulse=impulse;self.positionResidual=positionResidual;self.velocityResidual=velocityResidual
    }
}
