import MechanicsCore
import MechanicsNumerics
import MechanicsCompiler
public protocol DriveEvaluating: Sendable {
    func step(law:ScalarServo,state:ActuatorState,sample:ActuatorSample,command:DriveCommand,dt:Double,
              energyTolerance:NumericalTolerance,work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> ActuatorResponse
    func prescribedVelocity(binding:ActuatorBinding,model:CompiledMechanicalModel,time:Double,requested:Double,speedLimit:Double,
                            work:inout ActuationWork) throws(ActuationError) -> PrescribedVelocityCommand
}
