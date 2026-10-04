public struct OptimizationPolicy: Sendable {
    public let maximumVariables: Int, maximumRows: Int, maximumNonzeros: Int, maximumFactorEntries: Int, maximumCandidateBases: Int
    public let rankThreshold: Double, certificateAbsolute: Double, certificateRelative: Double
    public let luCapability: LinearCapability, curvatureCapability: LinearCapability
    public let linearTolerance: LinearTolerance<Double>
    public let isCancelled: @Sendable () -> Bool
    public init(maximumVariables: Int, maximumRows: Int, maximumNonzeros: Int, maximumFactorEntries: Int, maximumCandidateBases: Int,
        rankThreshold: Double, certificateAbsolute: Double, certificateRelative: Double, luCapability: LinearCapability,
        curvatureCapability: LinearCapability, linearTolerance: LinearTolerance<Double>, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(OptimizationCause) {
        guard maximumVariables > 0, maximumRows >= 0, maximumNonzeros >= 0, maximumFactorEntries >= 0, maximumCandidateBases >= 0,
            rankThreshold.isFinite, rankThreshold >= 0, certificateAbsolute.isFinite, certificateAbsolute >= 0,
            certificateRelative.isFinite, certificateRelative >= 0 else { throw .invalidProblem }
        self.maximumVariables=maximumVariables; self.maximumRows=maximumRows; self.maximumNonzeros=maximumNonzeros
        self.maximumFactorEntries=maximumFactorEntries; self.maximumCandidateBases=maximumCandidateBases
        self.rankThreshold=rankThreshold; self.certificateAbsolute=certificateAbsolute; self.certificateRelative=certificateRelative
        self.luCapability=luCapability; self.curvatureCapability=curvatureCapability; self.linearTolerance=linearTolerance; self.isCancelled=isCancelled
    }
}
