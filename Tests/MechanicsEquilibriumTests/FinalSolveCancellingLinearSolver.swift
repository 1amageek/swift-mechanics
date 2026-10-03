import Synchronization
import MechanicsNumerics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class FinalSolveCancellingLinearSolver: LinearSolving, Sendable {
    typealias Scalar = Double
    private let state = Mutex<(completedCalls: Int, cancelled: Bool)>((0, false))
    private let reference = ReferenceLinearSolver<Double>()
    var completedCalls: Int { state.withLock { $0.completedCalls } }
    var isCancelled: Bool { state.withLock { $0.cancelled } }

    func solve(_ matrix: DenseMatrix<Double>, rightHandSide: [Double], capability: LinearCapability,
               tolerance: LinearTolerance<Double>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        let result = try reference.solve(matrix, rightHandSide: rightHandSide, capability: capability, tolerance: tolerance, budget: budget)
        recordSuccessfulCompletion()
        return result
    }

    func solve(_ matrix: CSRMatrix<Double>, rightHandSide: [Double], capability: LinearCapability,
               tolerance: LinearTolerance<Double>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Double> {
        let result = try reference.solve(matrix, rightHandSide: rightHandSide, capability: capability, tolerance: tolerance, budget: budget)
        recordSuccessfulCompletion()
        return result
    }

    private func recordSuccessfulCompletion() {
        state.withLock {
            $0.completedCalls += 1
            if $0.completedCalls == 4 { $0.cancelled = true }
        }
    }
}
