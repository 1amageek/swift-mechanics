internal struct PlanarMomentumKernel {
    @inline(never) static func predict(state:PlanarState,source:PlanarSource,dt:Double,policy:PlanarPolicy,
                                      work:inout NumericalWork) throws(PlanarFluidError)->PlanarPredictor {
        try policy.poll();try source.validate(state.grid)
        let g=state.grid,n=g.count,m=g.cellMass,nu=g.nu,ix=1/g.dx,iy=1/g.dy
        let reserve=try planarNumerics { () throws(NumericalError) in try NumericalWork.product(7,n) }
        try planarNumerics { () throws(NumericalError) in try work.requireStorage(reserve) }
        let viscousFactor=try planarFinite(2*nu*dt*(ix*ix+iy*iy))
        guard viscousFactor <= policy.courantLimit else { throw .stability }
        var u=[Double](repeating:0,count:n),v=[Double](repeating:0,count:n)
        var ru=[Double](repeating:0,count:n),rv=[Double](repeating:0,count:n)
        var dmu=0.0,dup=0.0,leak=0.0,sourcePower=0.0,advPower=0.0,viscPower=0.0,injection=0.0,maxAdv=0.0,maxCourant=0.0
        let kinetic=try PlanarGeometry.energy(state.u,state.v,grid:g,policy:policy,work:&work)
        for k in 0..<n {
            try policy.poll();try planarNumerics { () throws(NumericalError) in try work.chargeOperations(200) }
            let l=g.left(k),r=g.right(k),b=g.below(k),t=g.above(k)
            let divergence=try planarFinite(PlanarGeometry.divergence(state.u,state.v,grid:g,at:k))
            guard abs(divergence) <= policy.divergenceAbsolute else { throw .originalResidual }
            let axR=0.5*(state.u[k]+state.u[r]),axL=0.5*(state.u[l]+state.u[k])
            let ayT=0.5*(state.v[g.above(l)]+state.v[t]),ayB=0.5*(state.v[l]+state.v[k])
            let bxR=0.5*(state.u[g.right(b)]+state.u[r]),bxL=0.5*(state.u[b]+state.u[k])
            let byT=0.5*(state.v[k]+state.v[t]),byB=0.5*(state.v[b]+state.v[k])
            let factorU=try planarFinite(dt*((max(axR,0)-min(axL,0))*ix+(max(ayT,0)-min(ayB,0))*iy))
            let factorV=try planarFinite(dt*((max(bxR,0)-min(bxL,0))*ix+(max(byT,0)-min(byB,0))*iy))
            let combined=try planarFinite(max(factorU,factorV)+viscousFactor)
            guard combined <= policy.courantLimit else { throw .stability }
            maxAdv=max(maxAdv,max(factorU,factorV));maxCourant=max(maxCourant,combined)
            let fuR=axR*(axR >= 0 ? state.u[k] : state.u[r]),fuL=axL*(axL >= 0 ? state.u[l] : state.u[k])
            let fuT=ayT*(ayT >= 0 ? state.u[k] : state.u[t]),fuB=ayB*(ayB >= 0 ? state.u[b] : state.u[k])
            let fvR=bxR*(bxR >= 0 ? state.v[k] : state.v[r]),fvL=bxL*(bxL >= 0 ? state.v[l] : state.v[k])
            let fvT=byT*(byT >= 0 ? state.v[k] : state.v[t]),fvB=byB*(byB >= 0 ? state.v[b] : state.v[k])
            let au=try planarFinite(-(fuR-fuL)*ix-(fuT-fuB)*iy),av=try planarFinite(-(fvR-fvL)*ix-(fvT-fvB)*iy)
            let lu=try planarFinite(nu*PlanarGeometry.laplacian(state.u,grid:g,at:k)),lv=try planarFinite(nu*PlanarGeometry.laplacian(state.v,grid:g,at:k))
            ru[k]=try planarFinite(au+lu+source.accelerationX);rv[k]=try planarFinite(av+lv+source.accelerationY)
            let du=try planarFinite(dt*ru[k]),dv=try planarFinite(dt*rv[k])
            u[k]=try planarFinite(state.u[k]+du);v[k]=try planarFinite(state.v[k]+dv)
            let ux=state.u[r]-state.u[k],uy=state.u[t]-state.u[k],vx=state.v[r]-state.v[k],vy=state.v[t]-state.v[k]
            dmu=try planarFinite(dmu+m*nu*(ux*ux*ix*ix+uy*uy*iy*iy+vx*vx*ix*ix+vy*vy*iy*iy))
            dup=try planarFinite(dup+0.5*m*(abs(axR)*ux*ux*ix+abs(ayT)*uy*uy*iy+abs(bxR)*vx*vx*ix+abs(byT)*vy*vy*iy))
            let da=(axR-axL)*ix+(ayT-ayB)*iy,db=(bxR-bxL)*ix+(byT-byB)*iy
            leak=try planarFinite(leak-0.5*m*(state.u[k]*state.u[k]*da+state.v[k]*state.v[k]*db))
            sourcePower=try planarFinite(sourcePower+m*(state.u[k]*source.accelerationX+state.v[k]*source.accelerationY))
            advPower=try planarFinite(advPower+m*(state.u[k]*au+state.v[k]*av))
            viscPower=try planarFinite(viscPower+m*(state.u[k]*lu+state.v[k]*lv))
            injection=try planarFinite(injection+0.5*m*(du*du+dv*dv))
        }
        try planarResidual(dt*(advPower+dup-leak),scale:dt*(abs(advPower)+dup+abs(leak)),absolute:policy.energyAbsolute,relative:policy.energyRelative)
        try planarResidual(dt*(viscPower+dmu),scale:dt*(abs(viscPower)+dmu),absolute:policy.energyAbsolute,relative:policy.energyRelative)
        let predictedK=try PlanarGeometry.energy(u,v,grid:g,policy:policy,work:&work)
        try planarResidual(predictedK-kinetic-dt*(sourcePower-dmu-dup+leak)-injection,
            scale:max(abs(predictedK-kinetic),dt*(abs(sourcePower)+dmu+dup+abs(leak))+injection),absolute:policy.energyAbsolute,relative:policy.energyRelative)
        try policy.poll()
        return PlanarPredictor(u:u,v:v,rateU:ru,rateV:rv,kinetic:kinetic,viscousPower:dmu,donorPower:dup,
            divergencePower:leak,sourcePower:sourcePower,injection:injection,advectiveFactor:maxAdv,viscousFactor:viscousFactor,courantFactor:maxCourant)
    }
}
