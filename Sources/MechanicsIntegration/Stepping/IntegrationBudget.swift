import MechanicsNumerics
import MechanicsRuntime

public struct IntegrationBudget: Sendable {
    public let maximumCoordinates: Int
    public let maximumAttempts: Int
    public let maximumAcceptedSteps: Int
    public let maximumOuterArithmetic: Int
    public let supplier: NumericalBudget
    public init(maximumCoordinates: Int, maximumAttempts: Int, maximumAcceptedSteps: Int, maximumOuterArithmetic: Int, supplier: NumericalBudget) throws(RuntimeFailure) {
        guard maximumCoordinates > 0, maximumAttempts > 0, maximumAttempts <= Int.max / 8, maximumAcceptedSteps > 0, maximumOuterArithmetic >= 0 else { throw RuntimeFailure(.invalidInput, message: "Invalid integration budget.") }
        self.maximumCoordinates = maximumCoordinates; self.maximumAttempts = maximumAttempts; self.maximumAcceptedSteps = maximumAcceptedSteps
        self.maximumOuterArithmetic = maximumOuterArithmetic; self.supplier = supplier
    }
}
