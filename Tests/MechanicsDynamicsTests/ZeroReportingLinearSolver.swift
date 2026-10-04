import SwiftMechanics
/// Negative fixture: reports valid supplier diagnostics with deliberately incorrect returned values.
struct ZeroReportingLinearSolver<Scalar: NumericalScalar>: LinearSolving {
    func solve(_ matrix: DenseMatrix<Scalar>, rightHandSide: [Scalar], capability: LinearCapability,
               tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Scalar> {
        let actual = try ReferenceLinearSolver<Scalar>().solve(matrix,rightHandSide:rightHandSide,capability:capability,tolerance:tolerance,budget:budget)
        return LinearSolution(values:[Scalar](repeating:0,count:rightHandSide.count),diagnostics:actual.diagnostics)
    }
    func solve(_ matrix: CSRMatrix<Scalar>, rightHandSide: [Scalar], capability: LinearCapability,
               tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Scalar> {
        try ReferenceLinearSolver<Scalar>().solve(matrix,rightHandSide:rightHandSide,capability:capability,tolerance:tolerance,budget:budget)
    }
}
