import SwiftMechanics
import Synchronization

struct RejectStabilityLinear: LinearSolving {
    typealias Scalar=Double
    func solve(_ matrix: DenseMatrix<Double>,rightHandSide: [Double],capability: LinearCapability,
               tolerance: LinearTolerance<Double>,budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> { throw .singular(rank:0,pivot:0) }
    func solve(_ matrix: CSRMatrix<Double>,rightHandSide: [Double],capability: LinearCapability,
               tolerance: LinearTolerance<Double>,budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> { throw .singular(rank:0,pivot:0) }
}
