import MechanicsNumerics
public protocol ScalarDifferentiating: Sendable {
    func evaluate(_ operation: SmoothScalarOperation, left: DirectionalScalar, right: DirectionalScalar?,
                  work: inout NumericalWork) throws(DerivativeError) -> DirectionalScalar
}
