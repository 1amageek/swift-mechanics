import MechanicsCompiler
import MechanicsRuntime

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol ExplicitIntegrating: Sendable {
    func advance(_ session: any RuntimeSessionOperating, model: CompiledMechanicalModel, equations: any SmoothODEEquations,
                 continuation: IntegrationContinuationProvider, to requestedTime: Double) throws(IntegrationFailure) -> IntegrationAdvanceResult
    func step(_ session: any RuntimeSessionOperating, model: CompiledMechanicalModel, equations: any SmoothODEEquations,
              continuation: IntegrationContinuationProvider) throws(IntegrationFailure) -> IntegrationAdvanceResult
}
