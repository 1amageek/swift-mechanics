import MechanicsNumerics

/// Providers own immutable calibrated semantics. All values are original SI derivatives.
public protocol StaticForceEvaluating<Scalar>: Sendable {
    associatedtype Scalar: NumericalScalar
    func validate(_ model: StaticForceModel, point: [Scalar], parameter: Scalar, work: inout NumericalWork) throws(StaticForceError)
    func gradient(_ model: StaticForceModel, point: [Scalar], parameter: Scalar, coordinate: Int, work: inout NumericalWork) throws(StaticForceError) -> Scalar
    func tangent(_ model: StaticForceModel, point: [Scalar], parameter: Scalar, row: Int, column: Int, work: inout NumericalWork) throws(StaticForceError) -> Scalar
    func parameterDerivative(_ model: StaticForceModel, point: [Scalar], parameter: Scalar, coordinate: Int, work: inout NumericalWork) throws(StaticForceError) -> Scalar
    func energy(_ model: StaticForceModel, point: [Scalar], parameter: Scalar, work: inout NumericalWork) throws(StaticForceError) -> Scalar
}
