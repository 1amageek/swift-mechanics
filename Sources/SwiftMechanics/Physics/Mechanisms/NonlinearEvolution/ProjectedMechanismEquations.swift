/// Physical stage correction and exact endpoint publication used by the common projected algorithm.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol ProjectedMechanismEquations: SmoothODEEquations {
    var model:CompiledMechanicalModel { get }
    /// Earliest declared smooth-interval boundary, strictly after the accepted time.
    func nextBoundary(after time:Double,through limit:Double,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> Double?
    func validateInitial(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure)
    func consistent(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> NonlinearMechanismState
    func writeAccepted(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension ProjectedMechanismEquations {
    /// Legacy conformers declare smooth intervals without internal trajectory knots.
    /// Conformers admitting declared knots must supply the boundary requirement witness.
    public func nextBoundary(after time:Double,through limit:Double,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> Double? { nil }
}
