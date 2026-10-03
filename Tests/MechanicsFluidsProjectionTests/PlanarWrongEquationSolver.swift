import MechanicsNumerics
struct PlanarWrongEquationSolver: LinearSolving, Sendable {
    typealias Scalar=Double
    func solve(_ matrix:DenseMatrix<Double>,rightHandSide rhs:[Double],capability:LinearCapability,tolerance:LinearTolerance<Double>,budget:NumericalBudget) throws(NumericalError)->LinearSolution<Double> {
        try ReferenceLinearSolver<Double>().solve(matrix,rightHandSide:[Double](repeating:0,count:rhs.count),capability:capability,tolerance:tolerance,budget:budget)
    }
    func solve(_ matrix:CSRMatrix<Double>,rightHandSide rhs:[Double],capability:LinearCapability,tolerance:LinearTolerance<Double>,budget:NumericalBudget) throws(NumericalError)->LinearSolution<Double> {
        try ReferenceLinearSolver<Double>().solve(matrix,rightHandSide:rhs,capability:capability,tolerance:tolerance,budget:budget)
    }
}
