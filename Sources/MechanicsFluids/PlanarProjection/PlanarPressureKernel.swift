import MechanicsNumerics
internal struct PlanarPressureKernel {
    @inline(never) static func project(state:PlanarState,dt:Double,policy:PlanarPolicy,linear:any LinearSolving<Double>,
                                      externalStorage:Int,work:inout NumericalWork) throws(PlanarFluidError)->PlanarProjectionResult {
        try policy.poll();try PlanarGeometry.duration(dt,state:state)
        let g=state.grid,n=g.count,reduced=n-1,ix=1/g.dx,iy=1/g.dy
        let square=try planarNumerics { () throws(NumericalError) in try NumericalWork.product(reduced,reduced) }
        let reserved=try planarNumerics { () throws(NumericalError) in
            try NumericalWork.sum(externalStorage,try NumericalWork.sum(square,try NumericalWork.sum(try NumericalWork.product(12,n),5)))
        }
        try planarNumerics { () throws(NumericalError) in try work.requireStorage(reserved) }
        let scale=try planarFinite(g.density/dt),correction=try planarFinite(dt/g.density)
        guard scale > 0,correction > 0 else { throw .nonfinite }
        let wx=try planarFinite(ix*ix),wy=try planarFinite(iy*iy),diagonal=try planarFinite(2*(wx+wy))
        var matrix=[Double](repeating:0,count:square),rhs=[Double](repeating:0,count:reduced)
        for k in 1..<n {
            try policy.poll();try planarNumerics { () throws(NumericalError) in try work.chargeOperations(16) }
            let row=k-1;matrix[row*reduced+row]=diagonal
            let l=g.left(k),r=g.right(k),b=g.below(k),t=g.above(k)
            if l != 0 { matrix[row*reduced+l-1] = -wx };if r != 0 { matrix[row*reduced+r-1] = -wx }
            if b != 0 { matrix[row*reduced+b-1] = -wy };if t != 0 { matrix[row*reduced+t-1] = -wy }
            rhs[row]=try planarFinite(-scale*PlanarGeometry.divergence(state.u,state.v,grid:g,at:k))
        }
        let dense=try planarNumerics { () throws(NumericalError) in try DenseMatrix(rows:reduced,columns:reduced,values:matrix) }
        let budget=try planarNumerics { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        let solution:LinearSolution<Double>
        do throws(NumericalError) {
            solution=try linear.solve(dense,rightHandSide:rhs,capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),tolerance:policy.linearTolerance,budget:budget)
        } catch { throw .numerical(error,failedSupplierWorkUnavailable:true) }
        try planarNumerics { () throws(NumericalError) in try work.absorb(solution.diagnostics.work,reservedStorage:reserved) }
        try policy.poll();guard solution.values.count == reduced else { throw .staleBinding }
        var pressure=[Double](repeating:0,count:n),u=[Double](repeating:0,count:n),v=[Double](repeating:0,count:n)
        for k in 1..<n { pressure[k]=solution.values[k-1] }
        for k in 0..<n {
            try policy.poll();try planarNumerics { () throws(NumericalError) in try work.chargeOperations(10) }
            u[k]=try planarFinite(state.u[k]-correction*PlanarGeometry.gradientX(pressure,grid:g,at:k))
            v[k]=try planarFinite(state.v[k]-correction*PlanarGeometry.gradientY(pressure,grid:g,at:k))
        }
        let output=try PlanarState(grid:g,time:state.time,sequence:state.sequence,u:u,v:v,pressure:pressure,source:state.source)
        let evidence=try verify(old:state,new:output,dt:dt,policy:policy,work:&work)
        try policy.poll();return PlanarProjectionResult(state:output,evidence:evidence)
    }
    @inline(never) private static func verify(old:PlanarState,new:PlanarState,dt:Double,policy:PlanarPolicy,
                                            work:inout NumericalWork) throws(PlanarFluidError)->PlanarProjectionEvidence {
        let g=new.grid,m=g.cellMass,scale=g.density/dt
        var maxDiv=0.0,maxP=0.0,maxForce=0.0,loss=0.0,leak=0.0,meanU=0.0,meanV=0.0,scaleU=0.0,scaleV=0.0
        for k in 0..<g.count {
            try policy.poll();try planarNumerics { () throws(NumericalError) in try work.chargeOperations(80) }
            let divergence=try planarFinite(PlanarGeometry.divergence(new.u,new.v,grid:g,at:k))
            guard abs(divergence) <= policy.divergenceAbsolute else { throw .originalResidual };maxDiv=max(maxDiv,abs(divergence))
            let lap=try planarFinite(-PlanarGeometry.laplacian(new.pressure,grid:g,at:k))
            let rhs=try planarFinite(-scale*PlanarGeometry.divergence(old.u,old.v,grid:g,at:k))
            let residual=try planarFinite(lap-rhs)
            try planarResidual(residual,scale:max(abs(lap),abs(rhs)),absolute:policy.pressureAbsolute,relative:policy.pressureRelative)
            maxP=max(maxP,abs(residual))
            let gu=PlanarGeometry.gradientX(new.pressure,grid:g,at:k),gv=PlanarGeometry.gradientY(new.pressure,grid:g,at:k)
            let du=new.u[k]-old.u[k],dv=new.v[k]-old.v[k]
            let fu=try planarFinite(m*(du/dt+gu/g.density)),fv=try planarFinite(m*(dv/dt+gv/g.density))
            try planarResidual(fu,scale:m*(abs(du/dt)+abs(gu/g.density)),absolute:policy.forceAbsolute,relative:policy.forceRelative)
            try planarResidual(fv,scale:m*(abs(dv/dt)+abs(gv/g.density)),absolute:policy.forceAbsolute,relative:policy.forceRelative)
            maxForce=max(maxForce,max(abs(fu),abs(fv)))
            meanU=try planarFinite(meanU+m*du/dt);meanV=try planarFinite(meanV+m*dv/dt)
            scaleU=try planarFinite(scaleU+m*abs(du/dt));scaleV=try planarFinite(scaleV+m*abs(dv/dt))
            loss=try planarFinite(loss+0.5*m*(du*du+dv*dv))
            leak=try planarFinite(leak+dt*m/g.density*new.pressure[k]*divergence)
        }
        try planarResidual(meanU,scale:scaleU,absolute:policy.forceAbsolute,relative:policy.forceRelative)
        try planarResidual(meanV,scale:scaleV,absolute:policy.forceAbsolute,relative:policy.forceRelative)
        let before=try PlanarGeometry.energy(old.u,old.v,grid:g,policy:policy,work:&work)
        let after=try PlanarGeometry.energy(new.u,new.v,grid:g,policy:policy,work:&work)
        let defect=try planarFinite(after-before+loss-leak)
        try planarResidual(defect,scale:max(abs(after-before),loss+abs(leak)),absolute:policy.energyAbsolute,relative:policy.energyRelative)
        return PlanarProjectionEvidence(maximumDivergence:maxDiv,maximumPressureResidual:maxP,maximumCorrectionForceResidual:maxForce,meanMomentumResidualX:meanU,meanMomentumResidualY:meanV,
            kineticBefore:before,kineticAfter:after,projectionLoss:loss,pressureResidualWork:leak,energyDefect:defect)
    }
}
