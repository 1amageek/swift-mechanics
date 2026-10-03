import MechanicsNumerics

public struct ComplementarityPolicy: Sendable {
    public let precision: NumericalPrecision
    public let backend: NumericalBackend
    public let tolerance: ConeTolerance
    public let maximumIterations: Int
    public let choleskyPivotThreshold: Double
    public let budget: NumericalBudget

    public init(precision: NumericalPrecision, backend: NumericalBackend, tolerance: ConeTolerance,
                maximumIterations: Int, choleskyPivotThreshold: Double, budget: NumericalBudget) throws(ComplementarityError) {
        guard maximumIterations >= 0, choleskyPivotThreshold.isFinite, choleskyPivotThreshold >= 0 else {
            throw .numerical(.invalidPolicy)
        }
        self.precision = precision; self.backend = backend; self.tolerance = tolerance
        self.maximumIterations = maximumIterations; self.choleskyPivotThreshold = choleskyPivotThreshold; self.budget = budget
    }
}
