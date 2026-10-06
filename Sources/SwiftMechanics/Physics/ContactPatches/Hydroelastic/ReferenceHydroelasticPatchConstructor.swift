public struct ReferenceHydroelasticPatchConstructor: HydroelasticPatchConstructing {
    private typealias A = HydroelasticArithmetic
    public init() {}
    public func construct(_ first: HydroelasticCellSelection,against second: HydroelasticPartner,origin: Vector3,
                          policy: HydroelasticPolicy,work: inout NumericalWork) throws(HydroelasticError) -> HydroelasticPatch {
        try A.check(policy)
        let secondNodeCount: Int
        switch second { case .field(let value): secondNodeCount=value.representation.mesh.mesh.nodes.count; default: secondNodeCount=0 }
        // Require all simultaneous local/output backing before allocating any geometry or loads.
        try A.storage(first.representation.mesh.mesh.nodes.count,secondNodeCount,&work)
        let a=try HydroelasticCellAdmission.prepare(first,policy,&work)
        var b: HydroelasticAffineCell?, normal: Vector3?, polygon: [Vector3]=[]
        switch second {
        case .rigidPlane(let input):
            try HydroelasticCellAdmission.plane(input,first,policy,&work)
            normal=input.representation.normal
            polygon=try HydroelasticPolygon.section(a,normal:input.representation.normal,point:input.representation.point,policy:policy,work:&work)
        case .field(let input):
            guard input.expectedModelRevision == first.expectedModelRevision else { throw .staleRepresentation }
            guard try A.same(input.sample,first.sample,policy,&work), input.sampleTimeSeconds == first.sampleTimeSeconds else { throw .sampleMismatch }
            guard try A.same(input.representation.mesh.mesh.frame,first.representation.mesh.mesh.frame,policy,&work) else { throw .frameMismatch }
            guard try !A.same(input.representation.body.id,first.representation.body.id,policy,&work) else { throw .invalidInput }
            let prepared=try HydroelasticCellAdmission.prepare(input,policy,&work); b=prepared
            let gradient=try A.sub(prepared.gradient,a.gradient,&work), magnitude=try A.norm(gradient,&work)
            if magnitude <= policy.gradientTolerance {
                // No normal is invented for a constant/ill-conditioned equality field.
                var positive=true, negative=true
                for i in 0..<4 {
                    let x=a.state.positions[a.cell.nodes[i]], pa=try a.pressure(x,&work), pb=try prepared.pressure(x,&work)
                    try A.charge(3,&work); let h=try A.finite(pa-pb)
                    positive=positive && h > policy.pressureTolerance; negative=negative && h < -policy.pressureTolerance
                }
                // FIXME(INCOMPLETE_IMPLEMENTATION): construct cannot assign a unique surface to coincident or ill-conditioned pressure volumes; actual regularized/interface ownership is required before success.
                guard positive || negative else { throw .ambiguousPressureVolume }
            } else {
                let n=try A.scale(gradient,1/magnitude,&work); normal=n
                let atBase=try prepared.pressure(a.basePoint,&work)
                try A.charge(3,&work); let distance=try A.finite((atBase-a.basePressure)/magnitude)
                let shift=try A.scale(n,distance,&work), point=try A.sub(a.basePoint,shift,&work)
                polygon=try HydroelasticPolygon.section(a,normal:n,point:point,policy:policy,work:&work)
                try HydroelasticPolygon.clip(&polygon,to:prepared,policy:policy,work:&work)
            }
        case .wholeMeshDiscovery:
            // FIXME(INCOMPLETE_IMPLEMENTATION): construct only handles a selected cell pair; complete mesh discovery needs current-volume non-overlap and shared patch ownership before claiming success.
            throw .unsupportedWholeMesh
        case .arbitrarySurface:
            // FIXME(INCOMPLETE_IMPLEMENTATION): construct has no calibrated curved/mesh rigid-surface representation or intersection producer; such surfaces must not become a plane fallback.
            throw .unsupportedSurface
        case .evolution:
            // FIXME(INCOMPLETE_IMPLEMENTATION): construct is an immutable instantaneous field query; coupled equilibrium, friction/damping and accepted evolution require real qualified solvers before success.
            throw .unsupportedEvolution
        }
        guard polygon.count <= policy.maximumVertices else { throw .capacityExceeded }
        let triangleCount=polygon.isEmpty ? 0 : polygon.count-2
        let rigidPlane: RigidPressurePlane?
        if case .rigidPlane(let input)=second { rigidPlane=input.representation } else { rigidPlane=nil }
        guard triangleCount <= 6, triangleCount <= policy.maximumTriangles else { throw .capacityExceeded }
        var firstLoads=[Vector3](repeating:.zero,count:first.representation.mesh.mesh.nodes.count)
        var secondLoads=[Vector3](repeating:.zero,count:secondNodeCount)
        var triangles: [HydroelasticTriangle]=[]; triangles.reserveCapacity(triangleCount)
        var integral=HydroelasticIntegral()
        if let normal, !polygon.isEmpty {
            for i in 1..<(polygon.count-1) {
                try A.check(policy)
                triangles.append(try HydroelasticTriangleIntegration.integrate(polygon[0],polygon[i],polygon[i+1],first:a,second:b,plane:rigidPlane,normal:normal,
                    origin:origin,policy:policy,firstLoads:&firstLoads,secondLoads:&secondLoads,integral:&integral,work:&work))
            }
        }
        return try finish(first,second:second,a:a,b:b,normal:normal,origin:origin,policy:policy,triangles:triangles,
                          firstLoads:firstLoads,secondLoads:secondLoads,integral:integral,work:&work)
    }
    private func finish(_ first: HydroelasticCellSelection,second: HydroelasticPartner,a: HydroelasticAffineCell,b: HydroelasticAffineCell?,normal: Vector3?,
                        origin: Vector3,policy: HydroelasticPolicy,triangles: [HydroelasticTriangle],firstLoads: [Vector3],secondLoads: [Vector3],
                        integral: HydroelasticIntegral,work: inout NumericalWork) throws(HydroelasticError) -> HydroelasticPatch {
        let firstTotals=try totals(firstLoads,state:a.state,origin:origin,policy:policy,work:&work)
        let negativeForce=try A.scale(integral.force,-1,&work), negativeMoment=try A.scale(integral.moment,-1,&work)
        let firstForceError=try A.sub(firstTotals.force,negativeForce,&work), firstMomentError=try A.sub(firstTotals.moment,negativeMoment,&work)
        var forceResidual=try A.norm(firstForceError,&work)/policy.forceScale
        var momentResidual=try A.norm(firstMomentError,&work)/policy.momentScale
        var powerResidual=try A.finite(abs(firstTotals.power-integral.surfacePowerFirst)/policy.powerScale)
        let secondPower: Double
        if let b {
            let other=try totals(secondLoads,state:b.state,origin:origin,policy:policy,work:&work)
            let forceError=try A.sub(other.force,integral.force,&work), momentError=try A.sub(other.moment,integral.moment,&work)
            forceResidual=max(forceResidual,try A.norm(forceError,&work)/policy.forceScale)
            momentResidual=max(momentResidual,try A.norm(momentError,&work)/policy.momentScale)
            let reactionForce=try A.add(firstTotals.force,other.force,&work)
            let reactionMoment=try A.add(firstTotals.moment,other.moment,&work)
            forceResidual=max(forceResidual,try A.norm(reactionForce,&work)/policy.forceScale)
            momentResidual=max(momentResidual,try A.norm(reactionMoment,&work)/policy.momentScale)
            powerResidual=max(powerResidual,try A.finite(abs(other.power-integral.surfacePowerSecond)/policy.powerScale))
            secondPower=other.power
        } else {
            guard case .rigidPlane(let input)=second else { throw .invalidInput }
            let plane=input.representation, lever=try A.sub(plane.point,origin,&work)
            let transport=try A.cross(lever,integral.force,&work), pointMoment=try A.sub(integral.moment,transport,&work)
            let linear=try A.dot(integral.force,plane.velocityAboutPoint.linear,&work)
            let angular=try A.dot(pointMoment,plane.velocityAboutPoint.angular,&work)
            secondPower=try A.finite(linear+angular)
            powerResidual=max(powerResidual,try A.finite(abs(secondPower-integral.surfacePowerSecond)/policy.powerScale))
        }
        try A.charge(16,&work)
        forceResidual=try A.finite(forceResidual); momentResidual=try A.finite(momentResidual); powerResidual=try A.finite(powerResidual)
        guard max(forceResidual,max(momentResidual,powerResidual)) <= policy.residualTolerance else { throw .residualRejected }
        let totalPower=try A.finite(firstTotals.power+secondPower)
        let flexibleLoads: [Vector3]?
        switch b { case .some: flexibleLoads=secondLoads; case .none: flexibleLoads=nil }
        try A.check(policy)
        return HydroelasticPatch(first:first,second:second,frame:a.state.frame,origin:origin,normal:normal,triangles:triangles,
            firstNodalForces:firstLoads,secondNodalForces:flexibleLoads,
            wrenchOnFirst:SpatialWrench(torque:negativeMoment,force:negativeForce),wrenchOnSecond:SpatialWrench(torque:integral.moment,force:integral.force),
            area:integral.area,integratedPressure:integral.pressure,firstPower:firstTotals.power,secondPower:secondPower,totalPower:totalPower,
            originalForceResidual:forceResidual,originalMomentResidual:momentResidual,originalPowerResidual:powerResidual,
            originalGeometryResidual:integral.geometryResidual,originalPressureDifferencePascals:integral.pressureDifference,work:work)
    }
    private func totals(_ loads: [Vector3],state: NodalState,origin: Vector3,policy: HydroelasticPolicy,
                        work: inout NumericalWork) throws(HydroelasticError) -> (force: Vector3,moment: Vector3,power: Double) {
        var force=Vector3.zero, moment=Vector3.zero, power=0.0
        for i in loads.indices {
            try A.check(policy)
            force=try A.add(force,loads[i],&work)
            let lever=try A.sub(state.positions[i],origin,&work), torque=try A.cross(lever,loads[i],&work)
            moment=try A.add(moment,torque,&work)
            let contraction=try A.dot(loads[i],state.velocities[i],&work)
            try A.charge(1,&work); power=try A.finite(power+contraction)
        }
        return (force,moment,power)
    }
}
