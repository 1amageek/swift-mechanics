import MechanicsNumerics
import MechanicsNonlinear

struct InvalidDerivativeEquation: NonlinearEquations {
    typealias Scalar = Double
    let identity = "invalid-derivative-buffer"
    let coordinateCount = 1
    func validateDomain(at point: [Double], work: inout NumericalWork) throws(NonlinearCause) {}
    func residual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(1) } catch { throw .numerical(error) }
        output[0] = point[0]-1
    }
    func jacobian(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        output.removeAll()
    }
    func originalResidual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(1) } catch { throw .numerical(error) }
        output[0] = point[0]-1
    }
}
