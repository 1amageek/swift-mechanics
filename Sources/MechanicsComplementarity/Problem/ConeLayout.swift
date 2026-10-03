import MechanicsNumerics

public enum ConeLayout: Equatable, Sendable {
    case nonnegativeOrthant(dimension: Int)
    /// Each block uses normal, tangent1, tangent2 coordinates.
    case associatedFrictionCones(coefficients: [Double])
    case nonAssociatedCoulomb(dimension: Int)

    public var coefficientCount: Int {
        switch self {
        case .associatedFrictionCones(let coefficients): coefficients.count
        case .nonnegativeOrthant, .nonAssociatedCoulomb: 0
        }
    }

    public func validatedDimension() throws(ComplementarityError) -> Int {
        switch self {
        case .nonnegativeOrthant(let dimension):
            guard dimension > 0 else { throw .numerical(.invalidDimensions) }
            return dimension
        case .associatedFrictionCones(let coefficients):
            guard !coefficients.isEmpty else { throw .numerical(.invalidDimensions) }
            for i in coefficients.indices {
                try complementarityCancelled()
                let mu = coefficients[i]
                guard mu.isFinite, mu >= 0, (1 + mu * mu).isFinite else { throw .invalidCone(block: i) }
            }
            return try complementarityNumerical { () throws(NumericalError) in try NumericalWork.product(3, coefficients.count) }
        case .nonAssociatedCoulomb: throw .unsupportedLaw
        }
    }
}
