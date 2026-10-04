import SwiftMechanics
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
struct PlanarCancellingSolver: LinearSolving, Sendable {
    typealias Scalar=Double
    let owner:PlanarCancellationOwner
    func solve(_ matrix:DenseMatrix<Double>,rightHandSide rhs:[Double],capability:LinearCapability,tolerance:LinearTolerance<Double>,budget:NumericalBudget) throws(NumericalError)->LinearSolution<Double> {
        let result=try ReferenceLinearSolver<Double>().solve(matrix,rightHandSide:rhs,capability:capability,tolerance:tolerance,budget:budget)
        owner.cancel();return result
    }
    func solve(_ matrix:CSRMatrix<Double>,rightHandSide rhs:[Double],capability:LinearCapability,tolerance:LinearTolerance<Double>,budget:NumericalBudget) throws(NumericalError)->LinearSolution<Double> {
        let result=try ReferenceLinearSolver<Double>().solve(matrix,rightHandSide:rhs,capability:capability,tolerance:tolerance,budget:budget)
        owner.cancel();return result
    }
}
