public struct TetrahedralPressurePatchIntegrator: PressurePatchIntegrating {
    public init() {}
    @inline(never)
    public func integrate(_ compliant: PressureBody,against rigid: PatchRepresentation,origin: Vector3,policy: PatchPolicy,
                          workspace: inout PatchWorkspace,work: inout NumericalWork) throws(PatchError) -> PressurePatchResult {
        try PatchArithmetic.check(policy)
        let plane: RigidPressurePlane
        switch rigid {
        case .rigidPlane(let value): plane=value
        // FIXME(INCOMPLETE_IMPLEMENTATION): Compliant-compliant equal-pressure interfaces and nonplane/rigid-rigid representations have no validated patch construction/pressure solve here. These production selections fail until original field/interface and refinement proof exists.
        case .compliantBody,.unsupportedRigidSurface: throw .unsupportedPair
        }
        let field=try PatchArithmetic.admit(compliant,plane,policy,&work)
        let worst=try PatchArithmetic.product(2,compliant.mesh.mesh.cells.count), n=compliant.mesh.mesh.nodes.count
        guard worst <= policy.maximumTriangles else { throw .capacityExceeded }
        let storage=try PatchArithmetic.sum(64,PatchArithmetic.sum(PatchArithmetic.product(128,worst),PatchArithmetic.product(3,n)))
        try PatchArithmetic.storage(storage,&work)
        var triangles: [PressureTriangle]=[]; triangles.reserveCapacity(worst)
        var nodal=[Vector3](repeating:.zero,count:n), integral=PatchIntegral()
        try build(compliant,plane:plane,field:field,origin:origin,policy:policy,workspace:&workspace,nodal:&nodal,triangles:&triangles,integral:&integral,work:&work)
        return try finish(compliant,plane:plane,field:field,origin:origin,policy:policy,nodal:nodal,triangles:triangles,integral:integral,work:&work)
    }
    @inline(never)
    private func build(_ body: PressureBody,plane: RigidPressurePlane,field: NodalPressureField,origin: Vector3,policy: PatchPolicy,workspace: inout PatchWorkspace,
                       nodal: inout [Vector3],triangles: inout [PressureTriangle],integral: inout PatchIntegral,work: inout NumericalWork) throws(PatchError) {
        for reference in body.mesh.referenceCells {
            try PatchArithmetic.check(policy)
            let count=try TetrahedralPlaneCutter.cut(reference,state:body.state,field:field,plane:plane,policy:policy,workspace:&workspace,work:&work)
            if count > 0 {
                for i in 1..<(count-1) {
                    try PatchArithmetic.check(policy)
                    triangles.append(try ExactPressureTriangleIntegrator.integrate(workspace.cut[0],workspace.cut[i],workspace.cut[i+1],cell:reference.cell,state:body.state,plane:plane,origin:origin,
                        policy:policy,nodal:&nodal,integral:&integral,work:&work))
                }
            }
        }
    }
    @inline(never)
    private func finish(_ body: PressureBody,plane: RigidPressurePlane,field: NodalPressureField,origin: Vector3,policy: PatchPolicy,nodal: [Vector3],triangles: [PressureTriangle],
                        integral: PatchIntegral,work: inout NumericalWork) throws(PatchError) -> PressurePatchResult {
        var force=Vector3.zero, moment=Vector3.zero, power=0.0
        for i in nodal.indices {
            try PatchArithmetic.check(policy)
            force=try PatchArithmetic.add(force,nodal[i],&work)
            moment=try PatchArithmetic.add(moment,PatchArithmetic.cross(PatchArithmetic.sub(body.state.positions[i],origin,&work),nodal[i],&work),&work)
            try PatchArithmetic.charge(1,&work); power=try PatchArithmetic.finite(power+PatchArithmetic.dot(nodal[i],body.state.velocities[i],&work))
        }
        let aboutPoint=try PatchArithmetic.sub(integral.moment,PatchArithmetic.cross(PatchArithmetic.sub(plane.point,origin,&work),integral.force,&work),&work)
        let rigidPower=try PatchArithmetic.finite(PatchArithmetic.dot(integral.force,plane.velocityAboutPoint.linear,&work)+PatchArithmetic.dot(aboutPoint,plane.velocityAboutPoint.angular,&work))
        try PatchArithmetic.charge(7,&work)
        let fr=try PatchArithmetic.finite(PatchArithmetic.norm(PatchArithmetic.add(force,integral.force,&work),&work)/policy.forceScale)
        let mr=try PatchArithmetic.finite(PatchArithmetic.norm(PatchArithmetic.add(moment,integral.moment,&work),&work)/policy.momentScale)
        let pr=try PatchArithmetic.finite(abs(power+PatchArithmetic.dot(plane.normal,integral.pressureVelocity,&work))/policy.powerScale)
        guard max(fr,max(mr,pr)) <= policy.residualTolerance else { throw .residualRejected }
        let oppositeForce=try PatchArithmetic.scale(integral.force,-1,&work), oppositeMoment=try PatchArithmetic.scale(integral.moment,-1,&work)
        let total=try PatchArithmetic.finite(power+rigidPower)
        try PatchArithmetic.check(policy)
        return PressurePatchResult(compliantBody:body.body,rigidBody:plane.body,frame:plane.frame,meshRevision:body.mesh.mesh.revision,pressureRevision:field.revision,planeRevision:plane.revision,
            source:field.source,materialIdentifiers:field.materialIdentifiers,origin:origin,triangles:triangles,nodalForces:nodal,area:integral.area,integratedPressure:integral.pressure,
            wrenchOnCompliant:SpatialWrench(torque:oppositeMoment,force:oppositeForce),wrenchOnRigid:SpatialWrench(torque:integral.moment,force:integral.force),compliantPower:power,rigidPower:rigidPower,totalPower:total,
            originalForceResidual:fr,originalMomentResidual:mr,originalPowerResidual:pr,work:work)
    }
}
