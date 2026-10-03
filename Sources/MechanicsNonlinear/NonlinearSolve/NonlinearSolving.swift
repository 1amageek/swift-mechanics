import MechanicsNumerics

public protocol NonlinearSolving<Scalar>: Sendable {
    associatedtype Scalar: NumericalScalar
    func solve(_ equations: any NonlinearEquations<Scalar>, initialPoint: [Scalar], policy: NonlinearPolicy<Scalar>) throws(NonlinearFailure<Scalar>) -> NonlinearSolution<Scalar>
}
