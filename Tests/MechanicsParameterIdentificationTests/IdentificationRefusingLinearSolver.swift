import SwiftMechanics
import Synchronization

@available(macOS 15,iOS 18,tvOS 18,watchOS 11,*)
final class IdentificationRefusingLinearSolver: LinearSolving, Sendable {
    typealias Scalar=Double
    private let count=Mutex(0)
    var calls:Int { count.withLock { $0 } }
    func solve(_ matrix:DenseMatrix<Double>,rightHandSide:[Double],capability:LinearCapability,
               tolerance:LinearTolerance<Double>,budget:NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        count.withLock { $0 += 1 }
        throw .unsupportedCapability
    }
    func solve(_ matrix:CSRMatrix<Double>,rightHandSide:[Double],capability:LinearCapability,
               tolerance:LinearTolerance<Double>,budget:NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        count.withLock { $0 += 1 }
        throw .unsupportedCapability
    }
}
