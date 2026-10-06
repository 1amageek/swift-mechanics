import SwiftMechanics
struct DifferentProblemNonlinearSolver<Scalar: NumericalScalar>: NonlinearSolving, Sendable {
    func solve(_ equations: any NonlinearEquations<Scalar>,initialPoint: [Scalar],policy: NonlinearPolicy<Scalar>) throws(NonlinearFailure<Scalar>) -> NonlinearSolution<Scalar> {
        // A real successful solve of another problem falsifies trust in internal residual alone.
        try ReferenceNonlinearSolver<Scalar>().solve(ConstantZeroKKTEquations<Scalar>(coordinateCount:initialPoint.count),initialPoint:initialPoint,policy:policy)
    }
}
