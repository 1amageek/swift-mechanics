import MechanicsCore
import MechanicsRuntime
import MechanicsNumerics
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public protocol ActuatorTrialOperating: Sendable {
    func servo(law:ScalarServo,command:DriveCommand,dt:Double,tolerance:NumericalTolerance,trial:inout RuntimeTrial,control:inout RuntimeStepControl,
               work:inout ActuationWork,numerical:inout NumericalWork) throws(RuntimeFailure) -> ActuatorResponse
}
