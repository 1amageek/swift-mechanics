public protocol SmoothNonlinearProgramProviding<Scalar>: Sendable {
    associatedtype Scalar: NumericalScalar
    var layout: NonlinearProgramLayout { get }
    func validateDomain(at point: [Scalar],work: inout NumericalWork) throws(NonlinearCause)
    func values(at point: [Scalar],into output: inout NonlinearProgramValues<Scalar>,work: inout NumericalWork) throws(NonlinearCause)
    func originalValues(at point: [Scalar],into output: inout NonlinearProgramValues<Scalar>,work: inout NumericalWork) throws(NonlinearCause)
    func lagrangianHessian(at point: [Scalar],equalityMultipliers: [Scalar],inequalityMultipliers: [Scalar],into sparseValues: inout [Scalar],work: inout NumericalWork) throws(NonlinearCause)
}
