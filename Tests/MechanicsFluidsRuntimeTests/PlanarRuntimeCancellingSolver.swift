import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct PlanarRuntimeCancellingSolver: LinearSolving, Sendable {
    typealias Scalar = Double
    let owner: PlanarRuntimeCancellationOwner
    func solve(_ matrix: DenseMatrix<Double>, rightHandSide: [Double], capability: LinearCapability,
               tolerance: LinearTolerance<Double>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        let result = try ReferenceLinearSolver<Double>().solve(matrix, rightHandSide: rightHandSide, capability: capability, tolerance: tolerance, budget: budget)
        owner.cancel(); return result
    }
    func solve(_ matrix: CSRMatrix<Double>, rightHandSide: [Double], capability: LinearCapability,
               tolerance: LinearTolerance<Double>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        let result = try ReferenceLinearSolver<Double>().solve(matrix, rightHandSide: rightHandSide, capability: capability, tolerance: tolerance, budget: budget)
        owner.cancel(); return result
    }
}
