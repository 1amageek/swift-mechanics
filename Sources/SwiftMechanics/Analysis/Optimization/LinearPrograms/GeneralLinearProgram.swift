/// Original dimensionless normalized LP: minimize constantCost + linearCost*x,
/// equalities*x = equalityRightHandSide, inequalities*x <= inequalityRightHandSide.
/// Metadata references map every original coordinate, row and objective to SI.
/// Absent bounds retain unrestricted sides; contradictory finite bounds are
/// admitted for phase-I certification instead of being silently repaired.
public struct GeneralLinearProgram: Sendable {
    public let metadata: OptimizationMetadata
    public let linearCost: [Double]
    public let constantCost: Double
    public let equalities: CSRMatrix<Double>?
    public let equalityRightHandSide: [Double]
    public let inequalities: CSRMatrix<Double>?
    public let inequalityRightHandSide: [Double]
    public let bounds: [LinearVariableBounds]
    public init(metadata: OptimizationMetadata, linearCost: [Double], constantCost: Double = 0,
                equalities: CSRMatrix<Double>? = nil, equalityRightHandSide: [Double] = [],
                inequalities: CSRMatrix<Double>? = nil, inequalityRightHandSide: [Double] = [], bounds: [LinearVariableBounds]) {
        self.metadata = metadata; self.linearCost = linearCost; self.constantCost = constantCost
        self.equalities = equalities; self.equalityRightHandSide = equalityRightHandSide
        self.inequalities = inequalities; self.inequalityRightHandSide = inequalityRightHandSide; self.bounds = bounds
    }
}
