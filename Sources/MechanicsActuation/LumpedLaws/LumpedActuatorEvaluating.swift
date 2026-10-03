import MechanicsCore
import MechanicsNumerics
public protocol LumpedActuatorEvaluating: Sendable {
    func motor(law:DCMotorLaw,state:ActuatorState,sample:ActuatorSample,voltage:Double,dt:Double,tolerance:NumericalTolerance,
               work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> ActuatorResponse
    func chamber(law:LinearChamberLaw,state:ActuatorState,sample:ActuatorSample,flow:Double,dt:Double,tolerance:NumericalTolerance,
                 work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> ActuatorResponse
    func muscle(law:SelectedMuscleLaw,state:ActuatorState,sample:ActuatorSample,activation:Double,dt:Double,tolerance:NumericalTolerance,
                work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> ActuatorResponse
}
