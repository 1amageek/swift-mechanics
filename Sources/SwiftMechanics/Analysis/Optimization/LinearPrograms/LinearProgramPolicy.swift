public struct LinearProgramPolicy: Sendable {
    public let maximumVariables: Int
    public let maximumRows: Int
    public let maximumNonzeros: Int
    public let maximumTableauEntries: Int
    public let maximumPivots: Int
    public let pivotThreshold: Double
    public let reducedCostTolerance: NumericalTolerance
    public let phaseOneTolerance: NumericalTolerance
    public let certificateTolerance: NumericalTolerance
    public let separationTolerance: NumericalTolerance
    public let isCancelled: @Sendable () -> Bool
    public init(maximumVariables: Int, maximumRows: Int, maximumNonzeros: Int, maximumTableauEntries: Int, maximumPivots: Int,
                pivotThreshold: Double, reducedCostTolerance: NumericalTolerance, phaseOneTolerance: NumericalTolerance,
                certificateTolerance: NumericalTolerance, separationTolerance: NumericalTolerance,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(LinearProgramCause) {
        guard maximumVariables > 0, maximumRows >= 0, maximumNonzeros >= 0, maximumTableauEntries >= 0, maximumPivots >= 0,
              pivotThreshold.isFinite, pivotThreshold > 0 else { throw .invalidProblem }
        self.maximumVariables = maximumVariables; self.maximumRows = maximumRows; self.maximumNonzeros = maximumNonzeros
        self.maximumTableauEntries = maximumTableauEntries; self.maximumPivots = maximumPivots; self.pivotThreshold = pivotThreshold
        self.reducedCostTolerance = reducedCostTolerance; self.phaseOneTolerance = phaseOneTolerance
        self.certificateTolerance = certificateTolerance; self.separationTolerance = separationTolerance; self.isCancelled = isCancelled
    }
}
