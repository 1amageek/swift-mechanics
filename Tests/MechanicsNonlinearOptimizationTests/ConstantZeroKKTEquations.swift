import SwiftMechanics
struct ConstantZeroKKTEquations<Scalar: NumericalScalar>: NonlinearEquations, Sendable {
    let coordinateCount: Int
    var identity: String { "different-root-problem" }
    func validateDomain(at point: [Scalar],work: inout NumericalWork) throws(NonlinearCause) {}
    func residual(at point: [Scalar],into output: inout [Scalar],work: inout NumericalWork) throws(NonlinearCause) { try fill(&output,work:&work) }
    func originalResidual(at point: [Scalar],into output: inout [Scalar],work: inout NumericalWork) throws(NonlinearCause) { try fill(&output,work:&work) }
    func jacobian(at point: [Scalar],into output: inout [Scalar],work: inout NumericalWork) throws(NonlinearCause) { try fill(&output,work:&work) }
    private func fill(_ output: inout [Scalar],work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(output.count) } catch { throw .numerical(error) }
        for i in output.indices { output[i]=0 }
    }
}
