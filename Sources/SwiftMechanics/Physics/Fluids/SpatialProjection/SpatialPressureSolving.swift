public protocol SpatialPressureSolving: Sendable {
    func solve(grid:SpatialGrid,rightHandSide:[Double],tolerance:LinearTolerance<Double>,budget:NumericalBudget,
               isCancelled:@Sendable ()->Bool) throws(NumericalError)->SpatialPressureSolution
}
