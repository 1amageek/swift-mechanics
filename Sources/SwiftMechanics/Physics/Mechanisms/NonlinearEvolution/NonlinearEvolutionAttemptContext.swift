@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class NonlinearEvolutionAttemptContext: Sendable {
    let equations:NonlinearMechanismEquation
    let continuation:IntegrationContinuationProvider
    let expected:RuntimeAcceptedState
    let target:Double
    let retry:Double?
    let budget:NumericalBudget
    let outerRemaining:Int
    init(equations:NonlinearMechanismEquation,continuation:IntegrationContinuationProvider,expected:RuntimeAcceptedState,
         target:Double,retry:Double?,budget:NumericalBudget,outerRemaining:Int) {
        self.equations=equations;self.continuation=continuation;self.expected=expected;self.target=target;self.retry=retry;self.budget=budget;self.outerRemaining=outerRemaining
    }
}
