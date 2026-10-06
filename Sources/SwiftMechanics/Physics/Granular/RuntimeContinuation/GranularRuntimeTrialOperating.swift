@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol GranularRuntimeTrialOperating: Sendable {
    func advance(model: CompiledMechanicalModel, duration: Double, trial: inout RuntimeTrial,
                 control: inout RuntimeStepControl, work: inout GranularRuntimeWork) throws(RuntimeFailure) -> GranularStepResult
}
