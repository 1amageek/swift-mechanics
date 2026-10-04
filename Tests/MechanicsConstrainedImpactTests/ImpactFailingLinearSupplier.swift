import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class ImpactFailingLinearSupplier: LinearSolving, Sendable {
    typealias Scalar = Double
    private let calls = Mutex(0)
    var callCount: Int { calls.withLock { $0 } }
    func solve(_ matrix: DenseMatrix<Double>, rightHandSide: [Double], capability: LinearCapability,
               tolerance: LinearTolerance<Double>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        calls.withLock { $0 += 1 }; throw .singular(rank:0,pivot:0)
    }
    func solve(_ matrix: CSRMatrix<Double>, rightHandSide: [Double], capability: LinearCapability,
               tolerance: LinearTolerance<Double>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        calls.withLock { $0 += 1 }; throw .singular(rank:0,pivot:0)
    }
}
