public struct LinearQuadraticPolicy: Sendable {
    public let maximumStates: Int
    public let maximumInputs: Int
    public let maximumMetadataBytes: Int
    public let maximumRiccatiIterations: Int
    public let tolerance: LinearTolerance<Double>
    public let semidefiniteTolerance: Double
    public let symmetryTolerance: Double
    public let budget: NumericalBudget
    public let isCancelled: @Sendable () -> Bool
    public init(maximumStates: Int, maximumInputs: Int, maximumMetadataBytes: Int, maximumRiccatiIterations: Int,
                tolerance: LinearTolerance<Double>, semidefiniteTolerance: Double, symmetryTolerance: Double,
                budget: NumericalBudget, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(LinearQuadraticFailure) {
        guard maximumStates > 0, maximumInputs > 0, maximumMetadataBytes > 0, maximumRiccatiIterations > 0,
              semidefiniteTolerance.isFinite, semidefiniteTolerance >= 0,
              symmetryTolerance.isFinite, symmetryTolerance >= 0 else {
            throw LinearQuadraticFailure(.invalidInput, phase: "policy")
        }
        self.maximumStates = maximumStates; self.maximumInputs = maximumInputs
        self.maximumMetadataBytes = maximumMetadataBytes; self.maximumRiccatiIterations = maximumRiccatiIterations
        self.tolerance = tolerance; self.semidefiniteTolerance = semidefiniteTolerance
        self.symmetryTolerance = symmetryTolerance; self.budget = budget; self.isCancelled = isCancelled
    }
}
