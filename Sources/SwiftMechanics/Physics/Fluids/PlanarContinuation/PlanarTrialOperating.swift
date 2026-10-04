
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol PlanarTrialOperating: Sendable {
    func advance(model: CompiledMechanicalModel, source: PlanarSource, duration: Double, policy: PlanarPolicy,
                 trial: inout RuntimeTrial, control: inout RuntimeStepControl,
                 numerical: inout NumericalWork, continuation: inout PlanarContinuationWork) throws(RuntimeFailure) -> PlanarStepResult
}
