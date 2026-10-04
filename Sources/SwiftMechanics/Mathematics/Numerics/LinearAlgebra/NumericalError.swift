public enum NumericalError: Error, Equatable, Sendable {
    case invalidDimensions
    case invalidIndex
    case invalidCSR
    case nonFiniteInput
    case nonFiniteResult
    case invalidPolicy
    case unsupportedCapability
    case singular(rank: Int, pivot: Int)
    case eliminationBreakdown(pivot: Int)
    case nonPositiveDefinite(pivot: Int)
    case nonsymmetric
    case resourceLimit(resource: NumericalResource, limit: Int)
    case residualRejected(value: Double, threshold: Double)
    case nonConvergence(iterations: Int, residual: Double)
    case cancelled
    case invalidTree(node: Int)
    case dimensionMismatch
    case perturbationExceeded(value: Double, maximum: Double)

    public var termination: NumericalTermination {
        switch self {
        case .invalidDimensions, .invalidIndex, .invalidCSR, .nonFiniteInput, .invalidPolicy, .invalidTree, .dimensionMismatch:
            .invalidInput
        case .unsupportedCapability: .unsupportedCapability
        case .singular: .singularSystem
        case .eliminationBreakdown: .unsupportedCapability
        case .nonPositiveDefinite: .matrixClassFailure
        case .nonsymmetric: .unsupportedCapability
        case .residualRejected, .nonConvergence, .perturbationExceeded: .nonConvergence
        case .resourceLimit: .resourceLimit
        case .cancelled: .cancelled
        case .nonFiniteResult: .arithmeticFailure
        }
    }
}
