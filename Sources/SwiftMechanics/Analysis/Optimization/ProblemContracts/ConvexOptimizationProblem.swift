public struct ConvexOptimizationProblem: Sendable {
    public let metadata: OptimizationMetadata
    public let linearCost: [Double]
    public let constantCost: Double
    public let hessian: DenseMatrix<Double>?
    public let equalities: CSRMatrix<Double>?
    public let equalityRightHandSide: [Double]
    public let inequalities: CSRMatrix<Double>?
    public let inequalityRightHandSide: [Double]
    public let lowerBounds: [Double], upperBounds: [Double]
    public init(metadata: OptimizationMetadata, linearCost: [Double], constantCost: Double = 0, hessian: DenseMatrix<Double>? = nil,
        equalities: CSRMatrix<Double>? = nil, equalityRightHandSide: [Double] = [], inequalities: CSRMatrix<Double>? = nil,
        inequalityRightHandSide: [Double] = [], lowerBounds: [Double], upperBounds: [Double]) {
        self.metadata=metadata; self.linearCost=linearCost; self.constantCost=constantCost; self.hessian=hessian
        self.equalities=equalities; self.equalityRightHandSide=equalityRightHandSide; self.inequalities=inequalities; self.inequalityRightHandSide=inequalityRightHandSide
        self.lowerBounds=lowerBounds; self.upperBounds=upperBounds
    }
}
