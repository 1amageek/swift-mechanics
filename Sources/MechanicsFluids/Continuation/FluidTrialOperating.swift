import MechanicsCompiler
import MechanicsRuntime
import MechanicsNumerics
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public protocol FluidTrialOperating: Sendable {
    func advance(model: CompiledMechanicalModel, boundary: FluidBoundary, duration: Double,
                 policy: FluidPolicy, trial: inout RuntimeTrial, control: inout RuntimeStepControl,
                 numerical: inout NumericalWork, bytes: inout FluidByteWork) throws(RuntimeFailure) -> FluidEvolution
}
