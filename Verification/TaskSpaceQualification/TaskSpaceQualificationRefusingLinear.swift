import SwiftMechanics

/// Linear failures expose no partial ledger in the original supplier protocol.
public struct TaskSpaceQualificationRefusingLinear: LinearSolving, Sendable {
    public typealias Scalar = Double
    public init() {}
    public func solve(_ matrix: DenseMatrix<Double>, rightHandSide: [Double], capability: LinearCapability,
                      tolerance: LinearTolerance<Double>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        throw .cancelled
    }
    public func solve(_ matrix: CSRMatrix<Double>, rightHandSide: [Double], capability: LinearCapability,
                      tolerance: LinearTolerance<Double>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        throw .cancelled
    }
}
