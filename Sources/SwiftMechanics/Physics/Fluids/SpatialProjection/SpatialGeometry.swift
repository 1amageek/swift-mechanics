internal struct SpatialGeometry {
    static func duration(_ dt:Double,state:SpatialState) throws(SpatialFluidError) {
        guard dt.isFinite,dt > 0,dt <= state.grid.limits.maximumStep else { throw .domain }
    }
    static func divergence(_ state:SpatialState,at k:Int)->Double {
        let g=state.grid
        return (state.u[g.neighbor(k,0,true)]-state.u[k])/g.dx +
            (state.v[g.neighbor(k,1,true)]-state.v[k])/g.dy + (state.w[g.neighbor(k,2,true)]-state.w[k])/g.dz
    }
    static func gradient(_ p:[Double],grid:SpatialGrid,at k:Int,axis:Int)->Double {
        (p[k]-p[grid.neighbor(k,axis,false)])/grid.spacing(axis)
    }
    static func laplacian(_ values:[Double],grid:SpatialGrid,at k:Int)->Double {
        var result=0.0
        for axis in 0..<3 {
            let inverse=1/grid.spacing(axis)
            result += ((values[grid.neighbor(k,axis,false)]-values[k]) +
                (values[grid.neighbor(k,axis,true)]-values[k]))*inverse*inverse
        };return result
    }
    static func energy(_ state:SpatialState,policy:SpatialPolicy,work:inout NumericalWork) throws(SpatialFluidError)->Double {
        var sum=0.0
        for k in 0..<state.grid.count {
            try policy.poll();try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(9) }
            sum=try spatialFinite(sum+0.5*state.grid.cellMass*(state.u[k]*state.u[k]+state.v[k]*state.v[k]+state.w[k]*state.w[k]))
        };return sum
    }
}
