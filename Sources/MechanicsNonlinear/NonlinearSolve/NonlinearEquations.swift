import MechanicsNumerics

public protocol NonlinearEquations<Scalar>: Sendable {
    associatedtype Scalar: NumericalScalar
    var identity: String { get }
    var coordinateCount: Int { get }
    func validateDomain(at point: [Scalar], work: inout NumericalWork) throws(NonlinearCause)
    func residual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause)
    func jacobian(at point: [Scalar], into rowMajorOutput: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause)
    func originalResidual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause)
}
