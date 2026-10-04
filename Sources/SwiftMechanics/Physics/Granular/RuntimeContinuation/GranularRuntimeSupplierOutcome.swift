internal final class GranularRuntimeSupplierOutcome: Sendable {
    let result: GranularStepResult?
    let failure: GranularError?
    init(result: GranularStepResult?,failure: GranularError?) { self.result=result;self.failure=failure }
}
