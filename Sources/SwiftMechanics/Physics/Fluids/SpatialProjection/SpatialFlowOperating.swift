public protocol SpatialFlowOperating: Sendable {
    func project(state:SpatialState,duration:Double,policy:SpatialPolicy,work:inout NumericalWork) throws(SpatialFluidError)->SpatialProjectionResult
    func step(state:SpatialState,source:SpatialSource,duration:Double,policy:SpatialPolicy,work:inout NumericalWork) throws(SpatialFluidError)->SpatialStepResult
}
