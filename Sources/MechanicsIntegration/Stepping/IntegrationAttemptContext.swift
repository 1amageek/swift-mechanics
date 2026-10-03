import MechanicsNumerics
import MechanicsRuntime

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IntegrationAttemptContext: Sendable {
    let equations: any SmoothODEEquations
    let continuation: IntegrationContinuationProvider
    let expected: RuntimeAcceptedState
    let target: Double
    let retry: Double?
    let supplierBudget: NumericalBudget
    let outerRemaining: Int
    init(equations: any SmoothODEEquations, continuation: IntegrationContinuationProvider,
         expected: RuntimeAcceptedState, target: Double, retry: Double?, supplierBudget: NumericalBudget, outerRemaining: Int) {
        self.equations=equations; self.continuation=continuation; self.expected=expected
        self.target=target; self.retry=retry; self.supplierBudget=supplierBudget; self.outerRemaining=outerRemaining
    }
}
