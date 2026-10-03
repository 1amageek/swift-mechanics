import MechanicsNumerics

public struct NonlinearPolicy<Scalar: NumericalScalar>: Sendable {
    public let strategy: NonlinearStrategy<Scalar>
    public let capability: LinearCapability
    public let tolerance: LinearTolerance<Scalar>
    public let referenceScale: Scalar
    public let minimumDirectionNorm: Scalar
    public let derivativeProbeDistance: Scalar
    public let derivativeAbsoluteTolerance: Scalar
    public let derivativeRelativeTolerance: Scalar
    public let maximumFactorEntries: Int
    public let estimateCondition: Bool
    public let budget: NumericalBudget
    public init(strategy: NonlinearStrategy<Scalar>, capability: LinearCapability, tolerance: LinearTolerance<Scalar>,
                referenceScale: Scalar, minimumDirectionNorm: Scalar, derivativeProbeDistance: Scalar,
                derivativeAbsoluteTolerance: Scalar, derivativeRelativeTolerance: Scalar, maximumFactorEntries: Int,
                estimateCondition: Bool, budget: NumericalBudget) throws(NumericalError) {
        guard referenceScale.isFinite, referenceScale > 0, minimumDirectionNorm.isFinite, minimumDirectionNorm >= 0,
              derivativeProbeDistance.isFinite, derivativeProbeDistance > 0, derivativeAbsoluteTolerance.isFinite,
              derivativeAbsoluteTolerance >= 0, derivativeRelativeTolerance.isFinite, derivativeRelativeTolerance >= 0,
              maximumFactorEntries >= 0 else { throw .invalidPolicy }
        switch strategy {
        case .newton: break
        case .lineSearch(let contraction, let sufficient, let minimum):
            guard contraction.isFinite, contraction > 0, contraction < 1, sufficient.isFinite, sufficient > 0, sufficient < 1,
                  minimum.isFinite, minimum > 0, minimum <= 1 else { throw .invalidPolicy }
        case .trustRegion(let initial, let minimum, let maximum, let accept, let shrink, let grow, let contraction, let expansion):
            guard initial.isFinite, minimum.isFinite, maximum.isFinite, minimum > 0, initial >= minimum, maximum >= initial,
                  accept.isFinite, shrink.isFinite, grow.isFinite, accept > 0, accept < shrink, shrink < grow, grow < 1,
                  contraction.isFinite, contraction > 0, contraction < 1, expansion.isFinite, expansion > 1 else { throw .invalidPolicy }
        }
        self.strategy = strategy; self.capability = capability; self.tolerance = tolerance; self.referenceScale = referenceScale
        self.minimumDirectionNorm = minimumDirectionNorm; self.derivativeProbeDistance = derivativeProbeDistance
        self.derivativeAbsoluteTolerance = derivativeAbsoluteTolerance; self.derivativeRelativeTolerance = derivativeRelativeTolerance
        self.maximumFactorEntries = maximumFactorEntries; self.estimateCondition = estimateCondition; self.budget = budget
    }
}
