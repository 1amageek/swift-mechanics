public protocol PlanarFlowOperating: Sendable {
    func project(state:PlanarState,duration:Double,policy:PlanarPolicy,work:inout NumericalWork) throws(PlanarFluidError)->PlanarProjectionResult
    func step(state:PlanarState,source:PlanarSource,duration:Double,policy:PlanarPolicy,work:inout NumericalWork) throws(PlanarFluidError)->PlanarStepResult
}
