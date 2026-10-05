internal struct SpatialMomentumKernel {
    @inline(never) static func predict(state:SpatialState,source:SpatialSource,dt:Double,policy:SpatialPolicy,
                                      work:inout NumericalWork) throws(SpatialFluidError)->SpatialPredictor {
        let g=state.grid,n=g.count,m=g.cellMass,nu=g.nu
        try policy.poll();try source.validate(g)
        try spatialNumerics { () throws(NumericalError) in try work.requireStorage(try NumericalWork.product(10,n)) }
        var inverseSquareSum=0.0
        for axis in 0..<3 { let inverse=1/g.spacing(axis);inverseSquareSum += inverse*inverse }
        try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(12) }
        let viscousFactor=try spatialFinite(2*nu*dt*inverseSquareSum)
        guard viscousFactor <= policy.courantLimit else { throw .stability }
        // Separate component buffers avoid per-cell materialization. Immutable component reads are COW borrows.
        var velocity=(0..<3).map { _ in [Double](repeating:0,count:n) }
        var rate=(0..<3).map { _ in [Double](repeating:0,count:n) }
        var dmu=0.0,dup=0.0,leak=0.0,sourcePower=0.0,advPower=0.0,viscPower=0.0,injection=0.0,maxAdv=0.0,maxCourant=0.0
        let kinetic=try SpatialGeometry.energy(state,policy:policy,work:&work)
        for k in 0..<n {
            try policy.poll()
            try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(18) }
            let divergence=try spatialFinite(SpatialGeometry.divergence(state,at:k))
            guard abs(divergence) <= policy.divergenceAbsolute else { throw .originalResidual }
            for component in 0..<3 {
                let old=state.component(component)
                var advection=0.0,dualDivergence=0.0,factor=0.0
                for axis in 0..<3 {
                    try policy.poll();try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(70) }
                    let r=g.neighbor(k,axis,true),l=g.neighbor(k,axis,false),inverse=1/g.spacing(axis)
                    let advector=state.component(axis)
                    let ar:Double,al:Double
                    if axis == component {
                        ar=0.5*(advector[k]+advector[r]);al=0.5*(advector[l]+advector[k])
                    } else {
                        ar=0.5*(advector[r]+advector[g.neighbor(r,component,false)])
                        al=0.5*(advector[k]+advector[g.neighbor(k,component,false)])
                    }
                    let fr=ar*(ar >= 0 ? old[k] : old[r]),fl=al*(al >= 0 ? old[l] : old[k])
                    advection=try spatialFinite(advection-(fr-fl)*inverse)
                    dualDivergence=try spatialFinite(dualDivergence+(ar-al)*inverse)
                    factor=try spatialFinite(factor+dt*(max(ar,0)-min(al,0))*inverse)
                    let delta=try spatialFinite(old[r]-old[k])
                    dmu=try spatialFinite(dmu+m*nu*delta*delta*inverse*inverse)
                    dup=try spatialFinite(dup+0.5*m*abs(ar)*delta*delta*inverse)
                }
                try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(70) }
                let combined=try spatialFinite(factor+viscousFactor)
                guard combined <= policy.courantLimit else { throw .stability }
                maxAdv=max(maxAdv,factor);maxCourant=max(maxCourant,combined)
                let viscous=try spatialFinite(nu*SpatialGeometry.laplacian(old,grid:g,at:k))
                let acceleration=source.component(component)
                let r=try spatialFinite(advection+viscous+acceleration),delta=try spatialFinite(dt*r)
                rate[component][k]=r;velocity[component][k]=try spatialFinite(old[k]+delta)
                leak=try spatialFinite(leak-0.5*m*old[k]*old[k]*dualDivergence)
                sourcePower=try spatialFinite(sourcePower+m*old[k]*acceleration)
                advPower=try spatialFinite(advPower+m*old[k]*advection)
                viscPower=try spatialFinite(viscPower+m*old[k]*viscous)
                injection=try spatialFinite(injection+0.5*m*delta*delta)
            }
        }
        try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(48) }
        try spatialResidual(dt*(advPower+dup-leak),scale:dt*(abs(advPower)+dup+abs(leak)),absolute:policy.energyAbsolute,relative:policy.energyRelative)
        try spatialResidual(dt*(viscPower+dmu),scale:dt*(abs(viscPower)+dmu),absolute:policy.energyAbsolute,relative:policy.energyRelative)
        var predictedK=0.0
        for k in 0..<n { try policy.poll();try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(9) }
            predictedK=try spatialFinite(predictedK+0.5*m*(velocity[0][k]*velocity[0][k]+velocity[1][k]*velocity[1][k]+velocity[2][k]*velocity[2][k]))
        }
        try spatialResidual(predictedK-kinetic-dt*(sourcePower-dmu-dup+leak)-injection,
            scale:max(abs(predictedK-kinetic),dt*(abs(sourcePower)+dmu+dup+abs(leak))+injection),absolute:policy.energyAbsolute,relative:policy.energyRelative)
        try policy.poll()
        return SpatialPredictor(velocity:velocity,rate:rate,kinetic:kinetic,viscousPower:dmu,donorPower:dup,
            divergencePower:leak,sourcePower:sourcePower,injection:injection,advectiveFactor:maxAdv,viscousFactor:viscousFactor,courantFactor:maxCourant)
    }
}
