public struct ReferencePlanarFlowSolver: PlanarFlowOperating, Sendable {
    public let linear:any LinearSolving<Double>
    public init(linear:any LinearSolving<Double>) { self.linear=linear }
    public func project(state:PlanarState,duration:Double,policy:PlanarPolicy,work:inout NumericalWork) throws(PlanarFluidError)->PlanarProjectionResult {
        try PlanarPressureKernel.project(state:state,dt:duration,policy:policy,linear:linear,externalStorage:0,work:&work)
    }
    public func step(state:PlanarState,source:PlanarSource,duration:Double,policy:PlanarPolicy,work:inout NumericalWork) throws(PlanarFluidError)->PlanarStepResult {
        try policy.poll();try PlanarGeometry.duration(duration,state:state);try source.validate(state.grid)
        guard state.sequence < UInt64.max else { throw .capacity }
        let time=try planarFinite(state.time+duration);guard time > state.time else { throw .domain }
        let predictor=try PlanarMomentumKernel.predict(state:state,source:source,dt:duration,policy:policy,work:&work)
        let tentative=try PlanarState(grid:state.grid,time:time,sequence:state.sequence+1,u:predictor.u,v:predictor.v,pressure:state.pressure,source:source)
        let external=try planarNumerics { () throws(NumericalError) in try NumericalWork.product(4,state.grid.count) }
        let projection=try PlanarPressureKernel.project(state:tentative,dt:duration,policy:policy,linear:linear,externalStorage:external,work:&work)
        let evidence=try PlanarWorkKernel.verify(old:state,new:projection.state,predictor:predictor,projection:projection.evidence,source:source,dt:duration,policy:policy,work:&work)
        try policy.poll();return PlanarStepResult(state:projection.state,evidence:evidence,projection:projection.evidence)
    }
}
