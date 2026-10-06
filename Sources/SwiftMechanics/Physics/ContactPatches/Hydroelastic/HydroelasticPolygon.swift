internal enum HydroelasticPolygon {
    private typealias A = HydroelasticArithmetic
    static func section(_ cell: HydroelasticAffineCell, normal: Vector3, point: Vector3,
                        policy: HydroelasticPolicy, work: inout NumericalWork) throws(HydroelasticError) -> [Vector3] {
        var result: [Vector3]=[]; result.reserveCapacity(8)
        // Fixed four distances; the selected interface may not pass through original vertices.
        let d0=try distance(cell.state.positions[cell.cell.nodes[0]],normal,point,&work)
        let d1=try distance(cell.state.positions[cell.cell.nodes[1]],normal,point,&work)
        let d2=try distance(cell.state.positions[cell.cell.nodes[2]],normal,point,&work)
        let d3=try distance(cell.state.positions[cell.cell.nodes[3]],normal,point,&work)
        let distances=HydroelasticCoordinates(n0:d0,n1:d1,n2:d2,n3:d3)
        for i in 0..<4 {
            try A.check(policy); try A.charge(1,&work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): construct refuses vertex/edge/face-coincident sections until explicit shared-feature ownership is implemented and physically qualified.
            guard abs(distances.value(i)) > policy.distanceTolerance else { throw .boundaryDegeneracy }
        }
        for i in 0..<4 { for j in (i+1)..<4 {
            try A.check(policy); try A.charge(4,&work)
            let a=distances.value(i), b=distances.value(j)
            if (a > 0) != (b > 0) {
                let t=try A.finite(a/(a-b))
                let x=try interpolate(cell.state.positions[cell.cell.nodes[i]],cell.state.positions[cell.cell.nodes[j]],t,&work)
                try append(x,to:&result,policy:policy,work:&work)
            }
        } }
        guard result.isEmpty || result.count == 3 || result.count == 4 else { throw .boundaryDegeneracy }
        if !result.isEmpty { try order(&result,normal:normal,policy:policy,work:&work) }
        return result
    }
    static func clip(_ polygon: inout [Vector3], to cell: HydroelasticAffineCell,
                     policy: HydroelasticPolicy, work: inout NumericalWork) throws(HydroelasticError) {
        var output: [Vector3]=[]; output.reserveCapacity(8)
        for face in 0..<4 {
            try A.check(policy); guard !polygon.isEmpty else { return }; output.removeAll(keepingCapacity:true)
            var previous=polygon[polygon.count-1]
            var previousDistance=try cell.coordinates(previous,&work).value(face)
            for current in polygon {
                try A.check(policy)
                let currentDistance=try cell.coordinates(current,&work).value(face)
                try A.charge(6,&work)
                // FIXME(INCOMPLETE_IMPLEMENTATION): construct refuses near-coincident clipping vertices; shared face/edge ownership and robust exact predicates are required before admitting these domains.
                guard abs(previousDistance) > policy.barycentricTolerance, abs(currentDistance) > policy.barycentricTolerance else { throw .boundaryDegeneracy }
                let previousInside=previousDistance > 0, currentInside=currentDistance > 0
                if previousInside != currentInside {
                    let t=try A.finite(previousDistance/(previousDistance-currentDistance))
                    let intersection=try interpolate(previous,current,t,&work)
                    try append(intersection,to:&output,policy:policy,work:&work)
                }
                if currentInside { try append(current,to:&output,policy:policy,work:&work) }
                previous=current; previousDistance=currentDistance
            }
            // Swap the two exclusive owners; no array materialization at a clipping stage.
            swap(&polygon,&output)
        }
        guard polygon.isEmpty || polygon.count >= 3 else { throw .boundaryDegeneracy }
    }
    private static func append(_ point: Vector3,to array: inout [Vector3],policy: HydroelasticPolicy,work: inout NumericalWork) throws(HydroelasticError) {
        try A.charge(1,&work); guard array.count < 8, array.count < policy.maximumVertices else { throw .capacityExceeded }; array.append(point)
    }
    private static func interpolate(_ a: Vector3,_ b: Vector3,_ t: Double,_ work: inout NumericalWork) throws(HydroelasticError) -> Vector3 {
        guard t > 0, t < 1 else { throw .boundaryDegeneracy }
        let delta=try A.sub(b,a,&work), weighted=try A.scale(delta,t,&work)
        return try A.add(a,weighted,&work)
    }
    private static func distance(_ x: Vector3,_ normal: Vector3,_ point: Vector3,_ work: inout NumericalWork) throws(HydroelasticError) -> Double {
        let offset=try A.sub(x,point,&work); return try A.dot(normal,offset,&work)
    }
    private static func order(_ polygon: inout [Vector3],normal: Vector3,policy: HydroelasticPolicy,work: inout NumericalWork) throws(HydroelasticError) {
        var center=Vector3.zero
        for x in polygon { center=try A.add(center,x,&work) }
        center=try A.scale(center,1/Double(polygon.count),&work)
        let radial=try A.sub(polygon[0],center,&work)
        let u=try A.core({ () throws(CoreError) in try radial.normalized() },&work), v=try A.cross(normal,u,&work)
        for i in 1..<polygon.count {
            let item=polygon[i]; var j=i
            while j > 0 {
                try A.check(policy)
                let a=try A.sub(item,center,&work), b=try A.sub(polygon[j-1],center,&work)
                let ax=try A.dot(a,u,&work), ay=try A.dot(a,v,&work), bx=try A.dot(b,u,&work), by=try A.dot(b,v,&work)
                try A.charge(10,&work)
                let ah=ay > 0 || (ay == 0 && ax >= 0), bh=by > 0 || (by == 0 && bx >= 0)
                let before=ah == bh ? ax*by-ay*bx > 0 : ah
                if !before { break }; polygon[j]=polygon[j-1]; j-=1
            }
            polygon[j]=item
        }
    }
}
