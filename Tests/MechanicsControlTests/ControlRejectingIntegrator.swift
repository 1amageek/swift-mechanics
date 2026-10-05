@testable import SwiftMechanics
import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
final class ControlRejectingIntegrator: ExplicitIntegrating, Sendable {
    private let first=Mutex(true)
    func advance(_ session:any RuntimeSessionOperating,model:CompiledMechanicalModel,equations:any SmoothODEEquations,continuation:IntegrationContinuationProvider,to requestedTime:Double) throws(IntegrationFailure) -> IntegrationAdvanceResult {
        let reject=first.withLock { value in let old=value;value=false;return old }
        if reject {
            do {
                _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    var work=NumericalWork(budget:continuation.policy.budget.supplier)
                    try equations.prepare(trial:&trial,work:&work,control:control)
                    _=try trial.nextRandom();try trial.setPosition(99,at:0)
                    return .reject
                }
            } catch {
                throw IntegrationFailure(cause:error,accepted:session.snapshot(),work:IntegrationWorkReport(unavailable:true),steps:0,rejects:0)
            }
            return try ReferenceExplicitIntegrator().advance(session,model:model,equations:equations,continuation:continuation,to:session.snapshot().checkpoint.physical.time)
        }
        return try ReferenceExplicitIntegrator().advance(session,model:model,equations:equations,continuation:continuation,to:requestedTime)
    }
    func step(_ session:any RuntimeSessionOperating,model:CompiledMechanicalModel,equations:any SmoothODEEquations,continuation:IntegrationContinuationProvider) throws(IntegrationFailure) -> IntegrationAdvanceResult {
        try ReferenceExplicitIntegrator().step(session,model:model,equations:equations,continuation:continuation)
    }
}
