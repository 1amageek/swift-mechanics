import SwiftMechanics

internal struct GeometricFailureLinear: LinearSolving {
    typealias Scalar=Double
    func solve(_ matrix:DenseMatrix<Double>,rightHandSide:[Double],capability:LinearCapability,tolerance:LinearTolerance<Double>,budget:NumericalBudget) throws(NumericalError) -> LinearSolution<Double> { throw .unsupportedCapability }
    func solve(_ matrix:CSRMatrix<Double>,rightHandSide:[Double],capability:LinearCapability,tolerance:LinearTolerance<Double>,budget:NumericalBudget) throws(NumericalError) -> LinearSolution<Double> { throw .unsupportedCapability }
}
