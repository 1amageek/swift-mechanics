import MechanicsNumerics

public enum NonlinearStrategy<Scalar: NumericalScalar>: Sendable {
    case newton
    case lineSearch(contraction: Scalar, sufficientDecrease: Scalar, minimumFraction: Scalar)
    case trustRegion(initialRadius: Scalar, minimumRadius: Scalar, maximumRadius: Scalar, acceptanceRatio: Scalar,
                     shrinkRatio: Scalar, growRatio: Scalar, contraction: Scalar, expansion: Scalar)
}
