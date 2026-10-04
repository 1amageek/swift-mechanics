internal struct PlanarGeometry {
    static func duration(_ dt:Double,state:PlanarState) throws(PlanarFluidError) {
        guard dt.isFinite,dt > 0,dt <= state.grid.limits.maximumStep else { throw .domain }
    }
    static func divergence(_ u:[Double],_ v:[Double],grid:PlanarGrid,at k:Int)->Double {
        (u[grid.right(k)]-u[k])/grid.dx+(v[grid.above(k)]-v[k])/grid.dy
    }
    static func gradientX(_ p:[Double],grid:PlanarGrid,at k:Int)->Double { (p[k]-p[grid.left(k)])/grid.dx }
    static func gradientY(_ p:[Double],grid:PlanarGrid,at k:Int)->Double { (p[k]-p[grid.below(k)])/grid.dy }
    static func laplacian(_ p:[Double],grid:PlanarGrid,at k:Int)->Double {
        let ix=1/grid.dx,iy=1/grid.dy
        return ((p[grid.left(k)]-p[k])+(p[grid.right(k)]-p[k]))*(ix*ix) +
        ((p[grid.below(k)]-p[k])+(p[grid.above(k)]-p[k]))*(iy*iy)
    }
    static func energy(_ u:[Double],_ v:[Double],grid:PlanarGrid,policy:PlanarPolicy,work:inout NumericalWork) throws(PlanarFluidError)->Double {
        let mass=grid.cellMass
        try planarNumerics { () throws(NumericalError) in try work.chargeOperations(5) }
        var sum=0.0
        for k in 0..<grid.count { try policy.poll();try planarNumerics { () throws(NumericalError) in try work.chargeOperations(6) }
            sum=try planarFinite(sum+0.5*mass*(u[k]*u[k]+v[k]*v[k]))
        };return sum
    }
}
