@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol ImplicitEulerIntegrating: Sendable {
    func step(_ session: any RuntimeSessionOperating, model: CompiledMechanicalModel,
              equations: any ImplicitODEEquations, to time: Double,
              policy: ImplicitEulerPolicy) throws(ImplicitIntegrationFailure) -> ImplicitEulerStepResult
}
