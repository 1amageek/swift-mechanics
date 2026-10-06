import SwiftMechanics

/// Negative dependency fixture: actual original solve followed by one declared contract violation.
public struct LinearQuadraticQualificationInvalidLinear: LinearSolving {
    public typealias Scalar = Double
    public enum Mode: Sendable { case wrongValue, wrongBudget, failureAfterSolve }
    public let mode: Mode
    public init(_ mode: Mode) { self.mode = mode }
    public func solve(_ matrix: DenseMatrix<Double>, rightHandSide: [Double], capability: LinearCapability,
        tolerance: LinearTolerance<Double>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        let original: any LinearSolving<Double> = ReferenceLinearSolver<Double>()
        let selected: NumericalBudget
        if case .wrongBudget = mode {
            selected = try NumericalBudget(scalarStorage: budget.scalarStorage,
                arithmeticOperations: NumericalWork.sum(budget.arithmeticOperations, 1), iterations: budget.iterations)
        } else { selected = budget }
        let result = try original.solve(matrix, rightHandSide: rightHandSide, capability: capability, tolerance: tolerance, budget: selected)
        if case .failureAfterSolve = mode { throw .singular(rank: 0, pivot: 0) }
        if case .wrongValue = mode {
            var values = result.values; values[0] += 1
            return LinearSolution(values: values, diagnostics: result.diagnostics)
        }
        return result
    }
    public func solve(_ matrix: CSRMatrix<Double>, rightHandSide: [Double], capability: LinearCapability,
        tolerance: LinearTolerance<Double>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        // The selected invalid-dependency witness exercises dense solves; CSR retains the original contract.
        try ReferenceLinearSolver<Double>().solve(matrix, rightHandSide: rightHandSide, capability: capability, tolerance: tolerance, budget: budget)
    }
}
