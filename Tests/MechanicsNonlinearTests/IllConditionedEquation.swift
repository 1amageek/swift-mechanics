import SwiftMechanics

struct IllConditionedEquation: NonlinearEquations {
    typealias Scalar = Double
    let identity = "diagonal-condition-1e8"
    let coordinateCount = 2
    func validateDomain(at point: [Double], work: inout NumericalWork) throws(NonlinearCause) {}
    func residual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(3) } catch { throw .numerical(error) }
        output[0] = 1e-8*(point[0]-1); output[1] = point[1]-2
    }
    func jacobian(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        output[0] = 1e-8; output[1] = 0; output[2] = 0; output[3] = 1
    }
    func originalResidual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(4) } catch { throw .numerical(error) }
        output[0] = 1e-8*point[0]-1e-8; output[1] = point[1]-2
    }
}
