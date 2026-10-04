internal enum MechanicalProductAssembler {
    @inline(never)
    static func evaluate(_ input: MechanicalDerivativeInput, _ d: MechanicalDirection, _ tree: TreeTangent,
                         _ system: RigidDynamicsSystem, _ p: DerivativePolicy, _ s: inout MechanicalDerivativeWorkspace,
                         _ w: inout NumericalWork) throws(DerivativeError) -> MechanicalTangent {
        let n=input.drive.count, nn=try DifferentialArithmetic.product(n,n)
        var mass=[Double](repeating:0,count:nn), dm=mass, bias=[Double](repeating:0,count:n), db=bias, force=bias, df=bias
        var kinetic=try DifferentialArithmetic.scalar(0), gravityPotential=kinetic, actualPower=kinetic, prescribedPower=kinetic
        let zeros=[Double](repeating:0,count:n)
        for index in input.inertias.indices {
            try DifferentialArithmetic.checkpoint(p)
            let body=try WorldBodyDifferential.evaluate(tree,input.inertias,d.inertias,index,&w)
            let required=try body.required(tree,body:index,acceleration:zeros,direction:zeros,&w)
            for j in 0..<n {
                try DifferentialArithmetic.checkpoint(p)
                let cj=try body.column(tree.columns[index*n+j],&w), inertiaColumn=try DifferentialArithmetic.apply(body.inertia,cj.angular,&w)
                for i in 0..<n {
                    let ci=try body.column(tree.columns[index*n+i],&w)
                    let angular=try DifferentialArithmetic.dot(ci.angular,inertiaColumn,&w)
                    let linear=try DifferentialArithmetic.multiply(body.mass,DifferentialArithmetic.dot(ci.linear,cj.linear,&w),&w)
                    let contribution=try DifferentialArithmetic.add(angular,linear,&w)
                    try DifferentialArithmetic.charge(2,&w)
                    mass[i*n+j]=try DifferentialArithmetic.finite(mass[i*n+j]+contribution.value)
                    dm[i*n+j]=try DifferentialArithmetic.finite(dm[i*n+j]+contribution.direction)
                }
                let b=try pair(cj,required,&w)
                try DifferentialArithmetic.charge(2,&w)
                bias[j]=try DifferentialArithmetic.finite(bias[j]+b.value); db[j]=try DifferentialArithmetic.finite(db[j]+b.direction)
            }
            let translational=try DifferentialArithmetic.multiply(body.mass,DifferentialArithmetic.dot(body.velocity,body.velocity,&w),&w)
            let angular=try DifferentialArithmetic.dot(body.omega,DifferentialArithmetic.apply(body.inertia,body.omega,&w),&w)
            kinetic=try DifferentialArithmetic.add(kinetic,DifferentialArithmetic.multiply(DifferentialArithmetic.add(translational,angular,&w),DifferentialArithmetic.scalar(0.5),&w),&w)
            if let gravity=input.gravity {
                try DifferentialArithmetic.charge(3,&w)
                let timeDerivative=try DifferentialArithmetic.core { () throws(CoreError) in try gravity.uniformTimeDerivative.scaled(by:d.tree.time) }
                let timeDirection=DifferentialVector(.zero,timeDerivative)
                let g=try DifferentialArithmetic.add(DifferentialVector(gravity.accelerationAtOrigin,d.gravity),timeDirection,&w)
                let gravityForce=try DifferentialArithmetic.scale(g,body.mass,&w)
                for j in 0..<n {
                    let c=try body.column(tree.columns[index*n+j],&w)
                    let q=try DifferentialArithmetic.dot(c.linear,gravityForce,&w)
                    try accumulate(q,j,&force,&df,&w)
                }
                actualPower=try DifferentialArithmetic.add(actualPower,DifferentialArithmetic.dot(gravityForce,body.velocity,&w),&w)
                prescribedPower=try DifferentialArithmetic.add(prescribedPower,DifferentialArithmetic.dot(gravityForce,body.drift.linear,&w),&w)
                gravityPotential=try DifferentialArithmetic.subtract(gravityPotential,DifferentialArithmetic.multiply(body.mass,DifferentialArithmetic.dot(g,body.position,&w),&w),&w)
            }
        }
        for index in input.bodyWrenches.indices {
            try DifferentialArithmetic.checkpoint(p)
            let load=input.bodyWrenches[index], dl=d.bodyWrenches[index]
            let body=try bodyIndex(input,load.body,p,&w), f=tree.frames[body]
            let wrench=try worldWrench(load,dl,f,input.tree.worldFrame,input.tree.bodies[body].frame,p,&w)
            for j in 0..<n { try accumulate(pair(tree.columns[body*n+j],wrench,&w),j,&force,&df,&w) }
            actualPower=try DifferentialArithmetic.add(actualPower,pair(f.velocity,wrench,&w),&w)
            let drift=tree.snapshot.bodies[body].prescribedDriftVelocity, dd=tree.bodies[body].prescribedDrift
            let driftJet=DifferentialMotion(DifferentialVector(drift.angular,dd.angular),DifferentialVector(drift.linear,dd.linear))
            prescribedPower=try DifferentialArithmetic.add(prescribedPower,pair(driftJet,wrench,&w),&w)
        }
        for index in input.generalizedForces.indices {
            for i in 0..<n {
                let q=try DifferentialArithmetic.scalar(input.generalizedForces[index].values[i],d.generalizedForces[index][i])
                try accumulate(q,i,&force,&df,&w)
                actualPower=try DifferentialArithmetic.add(actualPower,DifferentialArithmetic.multiply(q,DifferentialArithmetic.scalar(input.state.v[i],d.tree.velocity[i]),&w),&w)
            }
        }
        if input.forceProvider != nil {
            for i in 0..<n {
                let q=try DifferentialArithmetic.scalar(s.callbackValue[i],s.callbackDirection[i])
                try accumulate(q,i,&force,&df,&w)
                actualPower=try DifferentialArithmetic.add(actualPower,DifferentialArithmetic.multiply(q,DifferentialArithmetic.scalar(input.state.v[i],d.tree.velocity[i]),&w),&w)
            }
        }
        for i in 0..<nn { try DifferentialArithmetic.equal(mass[i],system.massMatrix[i],p,&w) }
        for i in 0..<n {
            try DifferentialArithmetic.equal(bias[i],system.inertialBias[i],p,&w)
            let original: Double
            do { original=try system.forces.total(at:i) } catch { throw .dynamics(error,failedSupplierWorkUnavailable:false) }
            try DifferentialArithmetic.equal(force[i],original,p,&w)
        }
        try DifferentialArithmetic.equal(gravityPotential.value,system.gravityPotential,p,&w)
        try DifferentialArithmetic.equal(actualPower.value,system.forces.actualPower,p,&w)
        try DifferentialArithmetic.equal(prescribedPower.value,system.forces.prescribedPower,p,&w)
        let virtual=try DifferentialArithmetic.subtract(actualPower,prescribedPower,&w)
        try DifferentialArithmetic.checkpoint(p)
        return MechanicalTangent(tree:tree,system:system,massMatrix:dm,inertialBias:db,totalForce:df,kineticEnergy:kinetic.direction,
            gravityPotential:gravityPotential.direction,actualLoadPower:actualPower.direction,virtualLoadPower:virtual.direction,
            prescribedLoadPower:prescribedPower.direction,parameterIDs:input.parameterIDs,parameterDimensions:input.parameterDimensions,inertiaDirections:d.inertias)
    }
    private static func accumulate(_ q: DirectionalScalar, _ i: Int, _ values: inout [Double], _ directions: inout [Double],
                                   _ w: inout NumericalWork) throws(DerivativeError) {
        try DifferentialArithmetic.charge(2,&w)
        values[i]=try DifferentialArithmetic.finite(values[i]+q.value); directions[i]=try DifferentialArithmetic.finite(directions[i]+q.direction)
    }
    private static func pair(_ motion: DifferentialMotion, _ wrench: DifferentialMotion, _ w: inout NumericalWork) throws(DerivativeError) -> DirectionalScalar {
        try DifferentialArithmetic.add(DifferentialArithmetic.dot(motion.angular,wrench.angular,&w),DifferentialArithmetic.dot(motion.linear,wrench.linear,&w),&w)
    }
    private static func bodyIndex(_ input: MechanicalDerivativeInput, _ id: EntityID, _ p: DerivativePolicy,
                                  _ w: inout NumericalWork) throws(DerivativeError) -> Int {
        for i in input.tree.bodies.indices {
            try DifferentialArithmetic.identityBytes(id,p,&w); try DifferentialArithmetic.identityBytes(input.tree.bodies[i].id,p,&w)
            if id == input.tree.bodies[i].id { return i }
        }
        throw .staleBinding
    }
    private static func worldWrench(_ load: BodyWrenchContribution, _ d: BodyWrenchDirection, _ f: DifferentialFrame,
                                    _ world: EntityID, _ body: EntityID, _ p: DerivativePolicy,
                                    _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialMotion {
        var force=DifferentialVector(load.wrench.force,d.wrench.force), torque=DifferentialVector(load.wrench.torque,d.wrench.torque)
        var point=DifferentialVector(load.referencePoint,d.referencePoint)
        try DifferentialArithmetic.identityBytes(load.frame,p,&w); try DifferentialArithmetic.identityBytes(world,p,&w)
        try DifferentialArithmetic.identityBytes(body,p,&w)
        if load.frame == body {
            force=try DifferentialArithmetic.apply(f.rotation,force,&w); torque=try DifferentialArithmetic.apply(f.rotation,torque,&w)
            point=try DifferentialArithmetic.add(f.translation,DifferentialArithmetic.apply(f.rotation,point,&w),&w)
        } else { guard load.frame == world else { throw .derivativeUnavailable } }
        torque=try DifferentialArithmetic.add(torque,DifferentialArithmetic.cross(DifferentialArithmetic.subtract(point,f.translation,&w),force,&w),&w)
        return DifferentialMotion(torque,force)
    }
}
