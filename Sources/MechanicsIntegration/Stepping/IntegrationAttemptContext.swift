import MechanicsNumerics
import MechanicsRuntime

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct IntegrationAttemptContext: Sendable {
    let equations: any SmoothODEEquations
    let continuation: IntegrationContinuationProvider
    let expected: RuntimeAcceptedState
    let target: Double
    let retry: Double?
    let supplierBudget: NumericalBudget
    let outerRemaining: Int
}
