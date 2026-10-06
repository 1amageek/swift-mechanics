internal struct SpatialPressureKernel {
    @inline(never) static func project(state:SpatialState,dt:Double,policy:SpatialPolicy,pressureSolver:any SpatialPressureSolving,
                                      externalStorage:Int,work:inout NumericalWork) throws(SpatialFluidError)->SpatialProjectionResult {
        try policy.poll();try SpatialGeometry.duration(dt,state:state)
        let g=state.grid,n=g.count
        let reserved=try spatialNumerics { () throws(NumericalError) in try NumericalWork.sum(externalStorage,try NumericalWork.product(14,n)) }
        try spatialNumerics { () throws(NumericalError) in try work.requireStorage(reserved) }
        try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(2) }
        let scale=try spatialFinite(g.density/dt),correction=try spatialFinite(dt/g.density)
        guard scale > 0,correction > 0 else { throw .nonfinite }
        var rhs=[Double](repeating:0,count:n)
        for k in 0..<n {
            try policy.poll();try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(18) }
            rhs[k]=try spatialFinite(-scale*SpatialGeometry.divergence(state,at:k))
        }
        let budget=try spatialNumerics { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        let solution:SpatialPressureSolution
        do throws(NumericalError) {
            solution=try pressureSolver.solve(grid:g,rightHandSide:rhs,tolerance:policy.linearTolerance,budget:budget,isCancelled:policy.isCancelled)
        } catch { throw .numerical(error,failedSupplierWorkUnavailable:true) }
        guard solution.work.budget == budget else { throw .numerical(.invalidPolicy,failedSupplierWorkUnavailable:true) }
        try spatialNumerics { () throws(NumericalError) in try work.absorb(solution.work,reservedStorage:reserved) }
        try policy.poll();guard solution.pressure.count == n else { throw .staleBinding }
        var pressure=solution.pressure,mean=0.0
        for k in 0..<n { try policy.poll();try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(1) };mean=try spatialFinite(mean+pressure[k]) }
        try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(1) };mean /= Double(n)
        var u=[Double](repeating:0,count:n),v=[Double](repeating:0,count:n),w=[Double](repeating:0,count:n)
        for k in 0..<n { try policy.poll();try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(1) };pressure[k]=try spatialFinite(pressure[k]-mean) }
        for k in 0..<n {
            try policy.poll();try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(15) }
            u[k]=try spatialFinite(state.u[k]-correction*SpatialGeometry.gradient(pressure,grid:g,at:k,axis:0))
            v[k]=try spatialFinite(state.v[k]-correction*SpatialGeometry.gradient(pressure,grid:g,at:k,axis:1))
            w[k]=try spatialFinite(state.w[k]-correction*SpatialGeometry.gradient(pressure,grid:g,at:k,axis:2))
        }
        let output=try SpatialState(grid:g,time:state.time,sequence:state.sequence,u:u,v:v,w:w,pressure:pressure,source:state.source)
        let evidence=try verify(old:state,new:output,dt:dt,policy:policy,work:&work)
        try policy.poll();return SpatialProjectionResult(state:output,evidence:evidence)
    }
    @inline(never) private static func verify(old:SpatialState,new:SpatialState,dt:Double,policy:SpatialPolicy,
                                            work:inout NumericalWork) throws(SpatialFluidError)->SpatialProjectionEvidence {
        let g=new.grid,m=g.cellMass
        var maxDiv=0.0,maxP=0.0,maxForce=0.0,loss=0.0,leak=0.0,gauge=0.0
        var momentum=[Double](repeating:0,count:3),forceScale=[Double](repeating:0,count:3)
        for k in 0..<g.count {
            try policy.poll();try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(256) }
            let divergence=try spatialFinite(SpatialGeometry.divergence(new,at:k))
            guard abs(divergence) <= policy.divergenceAbsolute else { throw .originalResidual };maxDiv=max(maxDiv,abs(divergence))
            let lap=try spatialFinite(-SpatialGeometry.laplacian(new.pressure,grid:g,at:k))
            let rhs=try spatialFinite(-g.density/dt*SpatialGeometry.divergence(old,at:k))
            let residual=try spatialFinite(lap-rhs)
            try spatialResidual(residual,scale:max(abs(lap),abs(rhs)),absolute:policy.pressureAbsolute,relative:policy.pressureRelative)
            maxP=max(maxP,abs(residual));gauge=try spatialFinite(gauge+new.pressure[k])
            for axis in 0..<3 {
                let gradient=SpatialGeometry.gradient(new.pressure,grid:g,at:k,axis:axis)
                let delta=try spatialFinite(new.component(axis)[k]-old.component(axis)[k])
                let force=try spatialFinite(m*(delta/dt+gradient/g.density))
                try spatialResidual(force,scale:m*(abs(delta/dt)+abs(gradient/g.density)),absolute:policy.forceAbsolute,relative:policy.forceRelative)
                maxForce=max(maxForce,abs(force));momentum[axis]=try spatialFinite(momentum[axis]+m*delta/dt)
                forceScale[axis]=try spatialFinite(forceScale[axis]+m*abs(delta/dt));loss=try spatialFinite(loss+0.5*m*delta*delta)
            }
            leak=try spatialFinite(leak+dt*m/g.density*new.pressure[k]*divergence)
        }
        try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(40) }
        try spatialResidual(gauge/Double(g.count),scale:0,absolute:policy.pressureGaugeAbsolute,relative:0)
        for axis in 0..<3 { try spatialResidual(momentum[axis],scale:forceScale[axis],absolute:policy.forceAbsolute,relative:policy.forceRelative) }
        let before=try SpatialGeometry.energy(old,policy:policy,work:&work),after=try SpatialGeometry.energy(new,policy:policy,work:&work)
        let defect=try spatialFinite(after-before+loss-leak)
        try spatialResidual(defect,scale:max(abs(after-before),loss+abs(leak)),absolute:policy.energyAbsolute,relative:policy.energyRelative)
        return SpatialProjectionEvidence(maximumDivergence:maxDiv,maximumPressureResidual:maxP,maximumCorrectionForceResidual:maxForce,
            meanMomentumResidualX:momentum[0],meanMomentumResidualY:momentum[1],meanMomentumResidualZ:momentum[2],
            kineticBefore:before,kineticAfter:after,projectionLoss:loss,pressureResidualWork:leak,energyDefect:defect)
    }
}
