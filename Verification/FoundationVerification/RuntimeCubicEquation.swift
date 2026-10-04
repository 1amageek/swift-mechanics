import SwiftMechanics

struct RuntimeCubicEquation<Scalar: NumericalScalar>: NonlinearEquations {
    let identity = "runtime-cubic"
    let coordinateCount = 1
    let falseInternalResidual: Bool

    func validateDomain(at point: [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(1) } catch { throw .numerical(error) }
        guard point.count == 1, point[0].isFinite else { throw .equation(.outsideDomain) }
    }

    func residual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(3) } catch { throw .numerical(error) }
        output[0] = falseInternalResidual ? 0 : point[0] * point[0] * point[0] - 1
    }

    func jacobian(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(2) } catch { throw .numerical(error) }
        output[0] = 3 * point[0] * point[0]
    }

    func originalResidual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(3) } catch { throw .numerical(error) }
        let square = point[0] * point[0]
        output[0] = square * point[0] - 1
    }
}
