import Synchronization
import MechanicsNumerics
import MechanicsNonlinear

@available(macOS 15.0, *)
final class MutatingLayoutEquation: NonlinearEquations, Sendable {
    typealias Scalar = Double
    let identity = "mutating-layout-contract-violation"
    private let countState = Mutex(1)
    var coordinateCount: Int { countState.withLock { $0 } }
    func validateDomain(at point: [Double], work: inout NumericalWork) throws(NonlinearCause) {}
    func residual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        countState.withLock { $0 = 2 }
        output[0] = 0; output.append(0)
    }
    func jacobian(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        output[0] = 1
    }
    func originalResidual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        output[0] = 0; output.append(0)
    }
}
