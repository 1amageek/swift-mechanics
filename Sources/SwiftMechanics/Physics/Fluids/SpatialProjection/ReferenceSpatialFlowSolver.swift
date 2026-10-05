public struct ReferenceSpatialFlowSolver: SpatialFlowOperating, Sendable {
    public let pressureSolver:any SpatialPressureSolving
    public init(pressureSolver:any SpatialPressureSolving) { self.pressureSolver=pressureSolver }
    public func project(state:SpatialState,duration:Double,policy:SpatialPolicy,work:inout NumericalWork) throws(SpatialFluidError)->SpatialProjectionResult {
        try SpatialPressureKernel.project(state:state,dt:duration,policy:policy,pressureSolver:pressureSolver,externalStorage:0,work:&work)
    }
    public func step(state:SpatialState,source:SpatialSource,duration:Double,policy:SpatialPolicy,work:inout NumericalWork) throws(SpatialFluidError)->SpatialStepResult {
        try policy.poll();try SpatialGeometry.duration(duration,state:state);try source.validate(state.grid)
        guard state.sequence < UInt64.max else { throw .capacity }
        try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(1) }
        let time=try spatialFinite(state.time+duration);guard time > state.time else { throw .domain }
        let predictor=try SpatialMomentumKernel.predict(state:state,source:source,dt:duration,policy:policy,work:&work)
        let tentative=try SpatialState(grid:state.grid,time:time,sequence:state.sequence+1,u:predictor.velocity[0],v:predictor.velocity[1],w:predictor.velocity[2],pressure:state.pressure,source:source)
        let external=try spatialNumerics { () throws(NumericalError) in try NumericalWork.product(8,state.grid.count) }
        let projection=try SpatialPressureKernel.project(state:tentative,dt:duration,policy:policy,pressureSolver:pressureSolver,externalStorage:external,work:&work)
        let evidence=try SpatialWorkKernel.verify(old:state,new:projection.state,predictor:predictor,projection:projection.evidence,source:source,dt:duration,policy:policy,work:&work)
        try policy.poll();return SpatialStepResult(state:projection.state,evidence:evidence,projection:projection.evidence)
    }
}
