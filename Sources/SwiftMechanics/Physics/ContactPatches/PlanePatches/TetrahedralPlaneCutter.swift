internal enum TetrahedralPlaneCutter {
    @inline(never)
    static func cut(_ reference: ReferenceTetrahedron,state: NodalState,field: NodalPressureField,plane: RigidPressurePlane,policy: PatchPolicy,
                    workspace: inout PatchWorkspace,work: inout NumericalWork) throws(PatchError) -> Int {
        try PatchArithmetic.check(policy)
        let cell=reference.cell, x0=state.positions[cell.nodes[0]]
        let a=try PatchArithmetic.sub(state.positions[cell.nodes[1]],x0,&work), b=try PatchArithmetic.sub(state.positions[cell.nodes[2]],x0,&work), c=try PatchArithmetic.sub(state.positions[cell.nodes[3]],x0,&work)
        let edges=try PatchArithmetic.core({ () throws(CoreError) in try Matrix3(a.x,b.x,c.x,a.y,b.y,c.y,a.z,b.z,c.z)},&work)
        let f=try PatchArithmetic.core({ () throws(CoreError) in try edges.multiplied(by:reference.inverseEdges)},&work)
        let determinant=try PatchArithmetic.core({ () throws(CoreError) in try f.determinant()},&work)
        guard determinant > policy.minimumDeterminant else { throw .invertedCell(cell.identifier) }
        // Four fixed scalar distances, avoiding an array allocation per cell.
        var distance=PatchBarycentricWeights.zero
        for i in 0..<4 {
            let d=try PatchArithmetic.dot(plane.normal,PatchArithmetic.sub(state.positions[cell.nodes[i]],plane.point,&work),&work)
            guard abs(d) > policy.planeDistanceTolerance else {
                // FIXME(INCOMPLETE_IMPLEMENTATION): Plane-through-vertex/face cuts need a unique shared-face ownership and degeneracy policy. This production cutter refuses them until geometry/refinement evidence closes that branch.
                throw .degenerateCut
            }
            distance.set(i,d)
        }
        var count=0
        for i in 0..<4 { for j in (i+1)..<4 {
            try PatchArithmetic.charge(2,&work)
            let di=distance.value(i), dj=distance.value(j)
            if (di > 0) != (dj > 0) {
                guard count < 4 else { throw .degenerateCut }
                try PatchArithmetic.charge(8,&work)
                let t=try PatchArithmetic.finite(di/(di-dj)), s=try PatchArithmetic.finite(1-t)
                guard t > 0, t < 1 else { throw .degenerateCut }
                var weights=PatchBarycentricWeights.zero; weights.set(i,s); weights.set(j,t)
                let point=try PatchArithmetic.add(PatchArithmetic.scale(state.positions[cell.nodes[i]],s,&work),PatchArithmetic.scale(state.positions[cell.nodes[j]],t,&work),&work)
                let pressure=try PatchArithmetic.finite(s*field.pressurePascals[cell.nodes[i]]+t*field.pressurePascals[cell.nodes[j]])
                workspace.cut[count]=PatchVertex(point:point,weights:weights,pressure:pressure); count+=1
            }
        } }
        if count == 0 { return 0 }
        guard count == 3 || count == 4 else { throw .degenerateCut }
        try order(count,normal:plane.normal,workspace:&workspace,work:&work)
        return count
    }
    @inline(never)
    private static func order(_ count: Int,normal: Vector3,workspace: inout PatchWorkspace,work: inout NumericalWork) throws(PatchError) {
        var center=Vector3.zero
        for i in 0..<count { center=try PatchArithmetic.add(center,workspace.cut[i].point,&work) }
        center=try PatchArithmetic.scale(center,1/Double(count),&work)
        let radial=try PatchArithmetic.sub(workspace.cut[0].point,center,&work)
        let u=try PatchArithmetic.core({ () throws(CoreError) in try radial.normalized()},&work)
        let v=try PatchArithmetic.cross(normal,u,&work)
        // Insertion sort over four records in the existing owner; no angle functions or index arrays.
        for i in 1..<count {
            let item=workspace.cut[i]; var j=i
            while j > 0, try precedes(item,workspace.cut[j-1],center:center,u:u,v:v,work:&work) { workspace.cut[j]=workspace.cut[j-1]; j-=1 }
            workspace.cut[j]=item
        }
    }
    private static func precedes(_ a: PatchVertex,_ b: PatchVertex,center: Vector3,u: Vector3,v: Vector3,work: inout NumericalWork) throws(PatchError) -> Bool {
        let da=try PatchArithmetic.sub(a.point,center,&work), db=try PatchArithmetic.sub(b.point,center,&work)
        let ax=try PatchArithmetic.dot(da,u,&work), ay=try PatchArithmetic.dot(da,v,&work), bx=try PatchArithmetic.dot(db,u,&work), by=try PatchArithmetic.dot(db,v,&work)
        try PatchArithmetic.charge(10,&work)
        let ah=ay > 0 || (ay == 0 && ax >= 0), bh=by > 0 || (by == 0 && bx >= 0)
        return ah == bh ? ax*by-ay*bx > 0 : ah
    }
}
