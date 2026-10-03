import MechanicsNumerics
import MechanicsNonlinear

struct CubicEquation<Scalar: NumericalScalar>: NonlinearEquations {
    let identity = "manufactured-cubic"
    let coordinateCount = 1
    let upperBound: Scalar?
    let derivativeMultiplier: Scalar
    let dishonestInternalResidual: Bool
    let cancelOnOriginal: Bool
    init(upperBound: Scalar? = nil, derivativeMultiplier: Scalar = 1, dishonestInternalResidual: Bool = false, cancelOnOriginal: Bool = false) {
        self.upperBound = upperBound; self.derivativeMultiplier = derivativeMultiplier; self.dishonestInternalResidual = dishonestInternalResidual; self.cancelOnOriginal = cancelOnOriginal
    }
    func validateDomain(at point: [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        if let upperBound {
            do { try work.chargeOperations(1) } catch { throw .numerical(error) }
            if point[0] > upperBound { throw .equation(.outsideDomain) }
        }
    }
    func residual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(3) } catch { throw .numerical(error) }
        output[0] = dishonestInternalResidual ? 0 : point[0]*point[0]*point[0]-1
    }
    func jacobian(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(3) } catch { throw .numerical(error) }
        output[0] = 3*point[0]*point[0]*derivativeMultiplier
    }
    func originalResidual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(3) } catch { throw .numerical(error) }
        let square = point[0]*point[0]
        output[0] = square*point[0]-1
        if cancelOnOriginal {
            // The task handle stays inside its synchronous borrow; no handle escapes.
            withUnsafeCurrentTask { task in task?.cancel() }
        }
    }
}
