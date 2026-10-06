internal enum RefinementTopology {
    static func faces(_ cells: [TetrahedronCell], policy p: RefinementPolicy,
                      work: inout NumericalWork) throws(RefinementError) -> [RefinementFace] {
        let count = try RefinementArithmetic.product(4,cells.count)
        guard count <= p.maximumFaces else { throw .capacityExceeded }
        var raw: [RefinementFace] = []; raw.reserveCapacity(count)
        let local = [[1,2,3],[0,3,2],[0,1,3],[0,2,1]]
        for (index,cell) in cells.enumerated() {
            for opposite in 0..<4 {
                try RefinementArithmetic.charge(8,p,&work)
                raw.append(RefinementFace(cell: cell.identifier, cellIndex: index, oppositeNode: opposite,
                    nodes: local[opposite].map { cell.nodes[$0] }, boundary: false))
            }
        }
        var faces: [RefinementFace] = []; faces.reserveCapacity(count)
        for i in raw.indices {
            var matches = 0
            for j in raw.indices where i != j {
                try RefinementArithmetic.charge(32,p,&work)
                if RefinementArithmetic.sameFace(raw[i].nodes,raw[j].nodes) {
                    matches += 1
                    guard RefinementArithmetic.oppositeFace(raw[i].nodes,raw[j].nodes) else { throw .invalidTopology }
                }
            }
            guard matches <= 1 else { throw .invalidTopology }
            faces.append(RefinementFace(cell: raw[i].cell, cellIndex: raw[i].cellIndex,
                oppositeNode: raw[i].oppositeNode, nodes: raw[i].nodes, boundary: matches == 0))
        }
        return faces
    }

    static func edges(_ mesh: TetrahedralMesh, policy p: RefinementPolicy,
                      work: inout NumericalWork) throws(RefinementError) -> [RefinementEdge] {
        var result: [RefinementEdge] = []
        result.reserveCapacity(min(p.maximumEdges,try RefinementArithmetic.product(6,mesh.cells.count)))
        for cell in mesh.cells {
            for a in 0..<4 { for b in (a+1)..<4 {
                let key = RefinementArithmetic.edge(cell.nodes[a],cell.nodes[b],nodes: mesh.nodes)
                var low = 0, high = result.count
                while low < high {
                    try RefinementArithmetic.charge(4,p,&work)
                    let middle = low+(high-low)/2
                    if RefinementArithmetic.edgeLess(result[middle],key) { low = middle+1 } else { high = middle }
                }
                if low < result.count, result[low] == key { continue }
                guard result.count < p.maximumEdges else { throw .capacityExceeded }
                try RefinementArithmetic.charge(try RefinementArithmetic.sum(8,result.count-low),p,&work)
                result.insert(key,at: low)
            } }
        }
        return result
    }

    static func midpoint(_ a: Int, _ b: Int, layout: Tet4RefinementLayout,
                         policy p: RefinementPolicy, work: inout NumericalWork) throws(RefinementError) -> Int {
        let key = RefinementArithmetic.edge(a,b,nodes: layout.source.mesh.mesh.nodes)
        var low = 0, high = layout.edges.count
        while low < high {
            try RefinementArithmetic.charge(4,p,&work)
            let middle = low+(high-low)/2
            if RefinementArithmetic.edgeLess(layout.edges[middle],key) { low = middle+1 } else { high = middle }
        }
        guard low < layout.edges.count, layout.edges[low] == key else { throw .invalidTopology }
        return try RefinementArithmetic.sum(layout.source.mesh.mesh.nodes.count,low)
    }

    static func conforming(_ mesh: TetrahedralMesh, policy p: RefinementPolicy,
                           work: inout NumericalWork) throws(RefinementError) {
        for i in mesh.cells.indices { for j in 0..<i {
            try RefinementArithmetic.charge(32,p,&work)
            let a = mesh.cells[i], b = mesh.cells[j]
            var shared: [Int] = []; shared.reserveCapacity(3)
            for node in a.nodes where b.nodes.contains(node) { shared.append(node) }
            guard shared.count <= 3 else { throw .invalidTopology }
            try intersections(a,b,targetShared: shared,mesh: mesh,policy: p,work: &work)
            try intersections(b,a,targetShared: shared,mesh: mesh,policy: p,work: &work)
        } }
    }

    private static func intersections(_ source: TetrahedronCell, _ target: TetrahedronCell,
                                      targetShared: [Int], mesh: TetrahedralMesh, policy p: RefinementPolicy,
                                      work: inout NumericalWork) throws(RefinementError) {
        let local = [[1,2,3],[0,3,2],[0,1,3],[0,2,1]]
        for a in 0..<4 { for b in (a+1)..<4 {
            let start = mesh.nodes[source.nodes[a]].referencePosition
            let end = mesh.nodes[source.nodes[b]].referencePosition
            var lower = 0.0, upper = 1.0, intersects = true
            for face in local {
                try RefinementArithmetic.charge(160,p,&work)
                let origin = mesh.nodes[target.nodes[face[0]]].referencePosition
                let u = try RefinementArithmetic.core { () throws(CoreError) in try mesh.nodes[target.nodes[face[1]]].referencePosition.subtracting(origin) }
                let v = try RefinementArithmetic.core { () throws(CoreError) in try mesh.nodes[target.nodes[face[2]]].referencePosition.subtracting(origin) }
                let normal = try RefinementArithmetic.core { () throws(CoreError) in try u.cross(v).normalized() }
                let d0 = try RefinementArithmetic.core { () throws(CoreError) in try start.subtracting(origin).dot(normal) }
                let d1 = try RefinementArithmetic.core { () throws(CoreError) in try end.subtracting(origin).dot(normal) }
                if d0 > p.conformityTolerance && d1 > p.conformityTolerance { intersects = false; break }
                if d0 > p.conformityTolerance || d1 > p.conformityTolerance {
                    let denominator = try RefinementArithmetic.finite(d1-d0)
                    guard denominator != 0 else { throw .nonconformingMesh }
                    let t = max(0,min(1,try RefinementArithmetic.finite(-d0/denominator)))
                    if d0 > p.conformityTolerance { lower = max(lower,t) } else { upper = min(upper,t) }
                    if lower > upper { intersects = false; break }
                }
            }
            if intersects {
                for t in [lower,upper] {
                    try RefinementArithmetic.charge(32,p,&work)
                    let point = try RefinementArithmetic.core { () throws(CoreError) in try start.scaled(by: 1-t).adding(end.scaled(by: t)) }
                    guard try inSharedSimplex(point,targetShared,mesh: mesh,policy: p,work: &work) else { throw .nonconformingMesh }
                }
            }
        } }
    }

    private static func inSharedSimplex(_ point: Vector3, _ shared: [Int], mesh: TetrahedralMesh,
                                        policy p: RefinementPolicy, work: inout NumericalWork) throws(RefinementError) -> Bool {
        try RefinementArithmetic.charge(256,p,&work)
        guard let first = shared.first else { return false }
        let origin = mesh.nodes[first].referencePosition
        let delta = try RefinementArithmetic.core { () throws(CoreError) in try point.subtracting(origin) }
        if shared.count == 1 { return try RefinementArithmetic.core { () throws(CoreError) in try delta.magnitude() } <= p.conformityTolerance }
        let u = try RefinementArithmetic.core { () throws(CoreError) in try mesh.nodes[shared[1]].referencePosition.subtracting(origin) }
        let uu = try RefinementArithmetic.core { () throws(CoreError) in try u.dot(u) }
        guard uu > 0 else { throw .nonconformingMesh }
        if shared.count == 2 {
            let t = max(0,min(1,try RefinementArithmetic.finite(RefinementArithmetic.core { () throws(CoreError) in try delta.dot(u) } / uu)))
            return try RefinementArithmetic.core { () throws(CoreError) in try delta.subtracting(u.scaled(by: t)).magnitude() } <= p.conformityTolerance
        }
        let v = try RefinementArithmetic.core { () throws(CoreError) in try mesh.nodes[shared[2]].referencePosition.subtracting(origin) }
        let uv = try RefinementArithmetic.core { () throws(CoreError) in try u.dot(v) }
        let vv = try RefinementArithmetic.core { () throws(CoreError) in try v.dot(v) }
        let du = try RefinementArithmetic.core { () throws(CoreError) in try delta.dot(u) }
        let dv = try RefinementArithmetic.core { () throws(CoreError) in try delta.dot(v) }
        let determinant = try RefinementArithmetic.finite(uu*vv-uv*uv)
        guard determinant > 0 else { throw .nonconformingMesh }
        let x = try RefinementArithmetic.finite((du*vv-dv*uv)/determinant)
        let y = try RefinementArithmetic.finite((dv*uu-du*uv)/determinant)
        let distance = try RefinementArithmetic.core { () throws(CoreError) in try delta.subtracting(u.scaled(by: x)).subtracting(v.scaled(by: y)).magnitude() }
        return x >= -p.barycentricTolerance && y >= -p.barycentricTolerance && x+y <= 1+p.barycentricTolerance && distance <= p.conformityTolerance
    }
}
