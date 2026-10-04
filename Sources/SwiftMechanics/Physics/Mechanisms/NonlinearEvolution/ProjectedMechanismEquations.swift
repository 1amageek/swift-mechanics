/// Physical stage correction and exact endpoint publication used by the common projected algorithm.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol ProjectedMechanismEquations: SmoothODEEquations {
    var model:CompiledMechanicalModel { get }
    func validateInitial(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure)
    func consistent(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> NonlinearMechanismState
    func writeAccepted(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure)
}
