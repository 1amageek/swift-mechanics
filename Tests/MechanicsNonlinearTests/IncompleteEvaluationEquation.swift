import MechanicsNumerics
import MechanicsNonlinear

struct IncompleteEvaluationEquation: NonlinearEquations {
    typealias Scalar = Double
    let identity = "incomplete-output-detection"
    let coordinateCount = 2
    let incompleteOriginal: Bool
    func validateDomain(at point: [Double], work: inout NumericalWork) throws(NonlinearCause) {}
    func residual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(2) } catch { throw .numerical(error) }
        output[0] = point[0]-1
        if incompleteOriginal { output[1] = point[1]-1 }
    }
    func jacobian(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        output[0] = 1; output[1] = 0; output[2] = 0; output[3] = 1
    }
    func originalResidual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(1) } catch { throw .numerical(error) }
        output[0] = point[0]-1
    }
}
