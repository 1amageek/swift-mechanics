import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class FaultyOptimizationLinearSolver<Scalar: NumericalScalar>: LinearSolving, Sendable {
    enum Mode: Sendable { case changedBudget, changedDimension, alteredRightHandSide }
    private let mode: Mode
    private let calls = Mutex(0)
    var invocationCount: Int { calls.withLock { $0 } }
    init(_ mode: Mode) { self.mode=mode }
    func solve(_ matrix: DenseMatrix<Scalar>,rightHandSide: [Scalar],capability: LinearCapability,
        tolerance: LinearTolerance<Scalar>,budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Scalar> {
        calls.withLock { $0 += 1 }
        switch mode {
        case .changedBudget:
            let replacement=try NumericalBudget(scalarStorage:budget.scalarStorage,arithmeticOperations:NumericalWork.sum(budget.arithmeticOperations,1),iterations:budget.iterations)
            return try ReferenceLinearSolver<Scalar>().solve(matrix,rightHandSide:rightHandSide,capability:capability,tolerance:tolerance,budget:replacement)
        case .alteredRightHandSide:
            var replacement=rightHandSide
            replacement[0] += 1
            return try ReferenceLinearSolver<Scalar>().solve(matrix,rightHandSide:replacement,capability:capability,tolerance:tolerance,budget:budget)
        case .changedDimension:
            let replacement=try DenseMatrix<Scalar>(rows:1,columns:1,values:[1])
            return try ReferenceLinearSolver<Scalar>().solve(replacement,rightHandSide:[0],capability:capability,tolerance:tolerance,budget:budget)
        }
    }
    func solve(_ matrix: CSRMatrix<Scalar>,rightHandSide: [Scalar],capability: LinearCapability,
        tolerance: LinearTolerance<Scalar>,budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Scalar> {
        calls.withLock { $0 += 1 }
        return try ReferenceLinearSolver<Scalar>().solve(matrix,rightHandSide:rightHandSide,capability:capability,tolerance:tolerance,budget:budget)
    }
}
