import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
struct ControlRefusingIntegrator: ExplicitIntegrating, Sendable {
    func advance(_ session:any RuntimeSessionOperating,model:CompiledMechanicalModel,equations:any SmoothODEEquations,
                 continuation:IntegrationContinuationProvider,to requestedTime:Double) throws(IntegrationFailure) -> IntegrationAdvanceResult {
        // Exercise the real integrator's typed invalid-target refusal; do not manufacture supplier work or an accepted result.
        try ReferenceExplicitIntegrator().advance(session,model:model,equations:equations,continuation:continuation,to:.nan)
    }
    func step(_ session:any RuntimeSessionOperating,model:CompiledMechanicalModel,equations:any SmoothODEEquations,
              continuation:IntegrationContinuationProvider) throws(IntegrationFailure) -> IntegrationAdvanceResult {
        try ReferenceExplicitIntegrator().step(session,model:model,equations:equations,continuation:continuation)
    }
}
