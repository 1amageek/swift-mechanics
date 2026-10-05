import SwiftMechanics

struct SpatialProjectionQualificationPressureFault: SpatialPressureSolving, Sendable {
    enum Mode: Equatable, Sendable { case wrongEquation, wrongSize, wrongBudget, supplierFailure }
    let mode: Mode
    func solve(grid: SpatialGrid, rightHandSide: [Double], tolerance: LinearTolerance<Double>,
               budget: NumericalBudget, isCancelled: @Sendable () -> Bool) throws(NumericalError) -> SpatialPressureSolution {
        if mode == .supplierFailure { throw .nonConvergence(iterations: 0, residual: 1) }
        let returnedBudget: NumericalBudget
        if mode == .wrongBudget {
            returnedBudget=try NumericalBudget(scalarStorage: budget.scalarStorage, arithmeticOperations: budget.arithmeticOperations+1, iterations: budget.iterations)
        } else { returnedBudget=budget }
        return SpatialPressureSolution(pressure: [Double](repeating: 0,count: mode == .wrongSize ? grid.count-1 : grid.count),
            work: NumericalWork(budget: returnedBudget), originalResidual: 0)
    }
}
