public struct LocalOptimizationPolicy: Sendable {
    public let nonlinear: NonlinearPolicy<Double>
    public let curvatureCapability: LinearCapability, curvatureTolerance: LinearTolerance<Double>
    public let maximumVariables: Int, maximumRows: Int, maximumNonzeros: Int, maximumDenseEntries: Int, maximumProviderScratchScalars: Int
    public let rankThreshold: Double, nullspaceTolerance: Double, absoluteTolerance: Double, relativeTolerance: Double, strictMultiplierMargin: Double, inactiveSlackMargin: Double
    public let isCancelled: @Sendable () -> Bool
    public init(nonlinear: NonlinearPolicy<Double>,curvatureCapability: LinearCapability,curvatureTolerance: LinearTolerance<Double>,
        maximumVariables: Int,maximumRows: Int,maximumNonzeros: Int,maximumDenseEntries: Int,maximumProviderScratchScalars: Int,
        rankThreshold: Double,nullspaceTolerance: Double,absoluteTolerance: Double,relativeTolerance: Double,strictMultiplierMargin: Double,inactiveSlackMargin: Double,
        isCancelled: @escaping @Sendable () -> Bool = { false }) throws(LocalOptimizationCause) {
        guard maximumVariables > 0, maximumRows >= 0, maximumNonzeros >= 0, maximumDenseEntries >= 0, maximumProviderScratchScalars >= 0 else { throw .invalidProblem }
        for x in [rankThreshold,nullspaceTolerance,absoluteTolerance,relativeTolerance,strictMultiplierMargin,inactiveSlackMargin] { guard x.isFinite, x >= 0 else { throw .invalidProblem } }
        self.nonlinear=nonlinear; self.curvatureCapability=curvatureCapability; self.curvatureTolerance=curvatureTolerance
        self.maximumVariables=maximumVariables; self.maximumRows=maximumRows; self.maximumNonzeros=maximumNonzeros; self.maximumDenseEntries=maximumDenseEntries
        self.maximumProviderScratchScalars=maximumProviderScratchScalars; self.rankThreshold=rankThreshold; self.nullspaceTolerance=nullspaceTolerance
        self.absoluteTolerance=absoluteTolerance; self.relativeTolerance=relativeTolerance; self.strictMultiplierMargin=strictMultiplierMargin; self.inactiveSlackMargin=inactiveSlackMargin; self.isCancelled=isCancelled
    }
}
