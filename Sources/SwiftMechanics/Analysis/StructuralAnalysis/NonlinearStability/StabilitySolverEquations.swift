/// Preserves the original equation through the fixed Embedded compiler's generic conformance route.
internal struct StabilitySolverEquations<Original: NonlinearEquations>: NonlinearEquations {
    typealias Scalar = Original.Scalar
    let original: Original
    var identity: String { original.identity }
    var coordinateCount: Int { original.coordinateCount }
    func validateDomain(at point: [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try original.validateDomain(at: point, work: &work)
    }
    func residual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try original.residual(at: point, into: &output, work: &work)
    }
    func jacobian(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try original.jacobian(at: point, into: &output, work: &work)
    }
    func originalResidual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try original.originalResidual(at: point, into: &output, work: &work)
    }
}
