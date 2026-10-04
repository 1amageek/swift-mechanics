
public struct ExplicitIntegrationPolicy: Sendable {
    public let method: ExplicitIntegrationMethod
    public let initialStep: Double
    public let minimumStep: Double
    public let maximumStep: Double
    public let safety: Double
    public let minimumFactor: Double
    public let maximumFactor: Double
    public let scales: [ODEErrorScale]
    public let maximumContinuationBytes: Int
    public let budget: IntegrationBudget
    public init(method: ExplicitIntegrationMethod, initialStep: Double, minimumStep: Double, maximumStep: Double,
                safety: Double, minimumFactor: Double, maximumFactor: Double, scales: [ODEErrorScale], maximumContinuationBytes: Int, budget: IntegrationBudget) throws(RuntimeFailure) {
        guard minimumStep.isFinite, maximumStep.isFinite, initialStep.isFinite, minimumStep > 0,
              initialStep >= minimumStep, initialStep <= maximumStep, safety.isFinite, safety > 0, safety < 1,
              minimumFactor.isFinite, minimumFactor > 0, minimumFactor < 1, maximumFactor.isFinite, maximumFactor >= 1,
              !scales.isEmpty, scales.count <= budget.maximumCoordinates, maximumContinuationBytes >= 0 else {
            throw RuntimeFailure(.invalidInput, message: "Invalid explicit method/step/error policy.")
        }
        self.method = method; self.initialStep = initialStep; self.minimumStep = minimumStep; self.maximumStep = maximumStep
        self.safety = safety; self.minimumFactor = minimumFactor; self.maximumFactor = maximumFactor
        self.scales = scales; self.maximumContinuationBytes = maximumContinuationBytes; self.budget = budget
    }
}
