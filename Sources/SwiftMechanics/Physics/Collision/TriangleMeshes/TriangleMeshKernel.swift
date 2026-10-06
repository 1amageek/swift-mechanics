internal enum TriangleMeshKernel {
    static func validate(_ vertices: [Vector3], _ faces: [TriangleMeshFace],
                         _ policy: TriangleMeshDistancePolicy, _ work: inout CollisionWork) throws(TriangleMeshError) {
        guard vertices.count >= 3, !faces.isEmpty else { throw .invalidMesh }
        try TriangleMeshMath.storage(vertices: vertices.count, faces: faces.count, work: &work)
        var used = [Bool](repeating: false, count: vertices.count), ids = Set<UInt64>()
        var edges: [(Int, Int, Int)] = []
        for (i, f) in faces.enumerated() {
            try TriangleMeshMath.charge(1024, &work)
            guard f.a >= 0, f.b >= 0, f.c >= 0, f.a < vertices.count, f.b < vertices.count, f.c < vertices.count,
                  f.a != f.b, f.a != f.c, f.b != f.c, ids.insert(f.id).inserted else { throw .invalidMesh }
            used[f.a] = true; used[f.b] = true; used[f.c] = true
            _ = try normal(f, vertices)
            edges.append((f.a, f.b, i)); edges.append((f.b, f.c, i)); edges.append((f.c, f.a, i))
        }
        guard used.allSatisfy({ $0 }) else { throw .invalidMesh }
        for i in vertices.indices { for j in 0..<i {
            try TriangleMeshMath.charge(8, &work)
            guard vertices[i] != vertices[j] else { throw .invalidMesh }
        } }
        var boundary = [Bool](repeating: false, count: edges.count)
        for i in edges.indices {
            var opposite = 0, same = 0
            for j in edges.indices where i != j {
                try TriangleMeshMath.charge(8, &work)
                if edges[i].0 == edges[j].1, edges[i].1 == edges[j].0 { opposite += 1 }
                if edges[i].0 == edges[j].0, edges[i].1 == edges[j].1 { same += 1 }
            }
            guard opposite <= 1, same == 0 else { throw .nonmanifoldMesh }
            boundary[i] = opposite == 0
        }
        for v in vertices.indices {
            var incident: [Int] = [], boundaryCount = 0
            for i in faces.indices {
                try TriangleMeshMath.charge(8, &work)
                let f = faces[i]
                if f.a == v || f.b == v || f.c == v { incident.append(i) }
            }
            for i in edges.indices {
                try TriangleMeshMath.charge(8, &work)
                if boundary[i], edges[i].0 == v || edges[i].1 == v { boundaryCount += 1 }
            }
            guard boundaryCount == 0 || boundaryCount == 2, let first = incident.first else { throw .nonmanifoldMesh }
            var reached = Set<Int>([first]), pending = [first]
            while let i = pending.popLast() {
                for j in incident {
                    try TriangleMeshMath.charge(16, &work)
                    if reached.contains(j) { continue }
                    try TriangleMeshMath.charge(64, &work)
                    let a = faces[i], b = faces[j]
                    let av = [a.a, a.b, a.c], bv = [b.a, b.b, b.c]
                    if av.contains(where: { $0 != v && bv.contains($0) }) { reached.insert(j); pending.append(j) }
                }
            }
            guard reached.count == incident.count else { throw .nonmanifoldMesh }
        }
        if policy == .certifiedTetrahedralSolid {
            guard vertices.count == 4, faces.count == 4, !boundary.contains(true) else { throw .uncertifiedSolid }
            for f in faces {
                let n = try normal(f, vertices)
                for i in vertices.indices where i != f.a && i != f.b && i != f.c {
                    try TriangleMeshMath.charge(64, &work)
                    guard try TriangleMeshMath.dot(n, TriangleMeshMath.sub(vertices[i], vertices[f.a])) < 0 else {
                        throw .uncertifiedSolid
                    }
                }
            }
        }
    }

    static func normal(_ face: TriangleMeshFace, _ vertices: [Vector3]) throws(TriangleMeshError) -> Vector3 {
        let a = try TriangleMeshMath.sub(vertices[face.b], vertices[face.a])
        let b = try TriangleMeshMath.sub(vertices[face.c], vertices[face.a])
        let scale = max(try TriangleMeshMath.norm(a), try TriangleMeshMath.norm(b))
        guard scale > 0 else { throw .degenerateTriangle(faceID: face.id) }
        let cross = try TriangleMeshMath.cross(TriangleMeshMath.scale(a, 1 / scale), TriangleMeshMath.scale(b, 1 / scale))
        guard try TriangleMeshMath.norm(cross) > 64 * Double.ulpOfOne else { throw .degenerateTriangle(faceID: face.id) }
        return try TriangleMeshMath.unit(cross)
    }

    static func barycentric(_ query: Vector3, _ face: TriangleMeshFace, _ vertices: [Vector3])
        throws(TriangleMeshError) -> Vector3 {
        let e1 = try TriangleMeshMath.sub(vertices[face.b], vertices[face.a])
        let e2 = try TriangleMeshMath.sub(vertices[face.c], vertices[face.a])
        let length = max(try TriangleMeshMath.norm(e1), try TriangleMeshMath.norm(e2))
        guard length > 0 else { throw .degenerateTriangle(faceID: face.id) }
        let a = try TriangleMeshMath.scale(e1, 1 / length), b = try TriangleMeshMath.scale(e2, 1 / length)
        let p = try TriangleMeshMath.scale(TriangleMeshMath.sub(query, vertices[face.a]), 1 / length)
        let aa = try TriangleMeshMath.dot(a, a), ab = try TriangleMeshMath.dot(a, b), bb = try TriangleMeshMath.dot(b, b)
        let ap = try TriangleMeshMath.dot(a, p), bp = try TriangleMeshMath.dot(b, p)
        let denominator = try TriangleMeshMath.finite(aa * bb - ab * ab)
        guard denominator > aa * bb * (64 * Double.ulpOfOne) else { throw .degenerateTriangle(faceID: face.id) }
        let y = try TriangleMeshMath.finite((bb * ap - ab * bp) / denominator)
        let z = try TriangleMeshMath.finite((aa * bp - ab * ap) / denominator)
        return try TriangleMeshMath.vector(1 - y - z, y, z)
    }

    static func reconstruct(_ w: Vector3, _ f: TriangleMeshFace, _ vertices: [Vector3])
        throws(TriangleMeshError) -> Vector3 {
        try TriangleMeshMath.add(TriangleMeshMath.scale(vertices[f.a], w.x),
            TriangleMeshMath.add(TriangleMeshMath.scale(vertices[f.b], w.y), TriangleMeshMath.scale(vertices[f.c], w.z)))
    }

    static func feature(_ w: Vector3, _ f: TriangleMeshFace) -> TriangleMeshFeature {
        if w.x == 1 { return .vertex(index: f.a) }; if w.y == 1 { return .vertex(index: f.b) }
        if w.z == 1 { return .vertex(index: f.c) }
        let a: Int, b: Int
        if w.x == 0 { a = f.b; b = f.c }
        else if w.y == 0 { a = f.a; b = f.c }
        else if w.z == 0 { a = f.a; b = f.b }
        else { return .face(id: f.id) }
        return .edge(firstVertex: min(a, b), secondVertex: max(a, b))
    }

    static func closest(_ query: Vector3, _ f: TriangleMeshFace, _ vertices: [Vector3])
        throws(TriangleMeshError) -> TriangleClosestFeature {
        let n = try normal(f, vertices)
        let height = try TriangleMeshMath.dot(n, TriangleMeshMath.sub(query, vertices[f.a]))
        let plane = try TriangleMeshMath.sub(query, TriangleMeshMath.scale(n, height))
        let weights = try barycentric(plane, f, vertices)
        if weights.x >= 0, weights.y >= 0, weights.z >= 0 {
            let point = try reconstruct(weights, f, vertices)
            return TriangleClosestFeature(point: point, weights: weights, feature: feature(weights, f), normal: n,
                distance: try TriangleMeshMath.norm(TriangleMeshMath.sub(query, point)))
        }
        var best: TriangleClosestFeature?
        let indices = [f.a, f.b, f.c]
        for k in 0..<3 {
            let first = k, second = (k + 1) % 3
            let a = vertices[indices[first]], edge = try TriangleMeshMath.sub(vertices[indices[second]], a)
            let length = try TriangleMeshMath.norm(edge), unit = try TriangleMeshMath.unit(edge)
            let projection = try TriangleMeshMath.dot(TriangleMeshMath.sub(query, a), unit)
            let fraction = max(0, min(1, try TriangleMeshMath.finite(projection / length)))
            let point = try TriangleMeshMath.add(a, TriangleMeshMath.scale(edge, fraction))
            var w = [0.0, 0.0, 0.0]; w[first] = 1 - fraction; w[second] = fraction
            let bary = try TriangleMeshMath.vector(w[0], w[1], w[2])
            let candidate = TriangleClosestFeature(point: point, weights: bary, feature: feature(bary, f), normal: n,
                distance: try TriangleMeshMath.norm(TriangleMeshMath.sub(query, point)))
            if let current = best {
                if candidate.distance < current.distance { best = candidate }
            } else { best = candidate }
        }
        guard let best else { throw .invalidMesh }; return best
    }

    static func triangleBounds(_ f: TriangleMeshFace, _ vertices: [Vector3]) throws(TriangleMeshError) -> TriangleMeshNode {
        let a = vertices[f.a], b = vertices[f.b], c = vertices[f.c]
        let lower = try TriangleMeshMath.vector(min(a.x, min(b.x, c.x)).nextDown,
            min(a.y, min(b.y, c.y)).nextDown, min(a.z, min(b.z, c.z)).nextDown)
        let upper = try TriangleMeshMath.vector(max(a.x, max(b.x, c.x)).nextUp,
            max(a.y, max(b.y, c.y)).nextUp, max(a.z, max(b.z, c.z)).nextUp)
        return TriangleMeshNode(minimum: lower, maximum: upper, left: -1, right: -1, face: -1)
    }

    static func union(_ a: TriangleMeshNode, _ b: TriangleMeshNode, left: Int, right: Int) throws(TriangleMeshError) -> TriangleMeshNode {
        let lower = try TriangleMeshMath.vector(min(a.minimum.x, b.minimum.x), min(a.minimum.y, b.minimum.y), min(a.minimum.z, b.minimum.z))
        let upper = try TriangleMeshMath.vector(max(a.maximum.x, b.maximum.x), max(a.maximum.y, b.maximum.y), max(a.maximum.z, b.maximum.z))
        return TriangleMeshNode(minimum: lower, maximum: upper, left: left, right: right, face: -1)
    }

    static func build(_ vertices: [Vector3], _ faces: [TriangleMeshFace], _ work: inout CollisionWork)
        throws(TriangleMeshError) -> [TriangleMeshNode] {
        try TriangleMeshMath.storage(vertices: vertices.count, faces: faces.count, work: &work)
        var nodes: [TriangleMeshNode] = [], centers: [Vector3] = []
        for f in faces {
            try TriangleMeshMath.charge(128, &work)
            centers.append(try TriangleMeshMath.add(vertices[f.a], TriangleMeshMath.add(
                TriangleMeshMath.scale(TriangleMeshMath.sub(vertices[f.b], vertices[f.a]), 1 / 3),
                TriangleMeshMath.scale(TriangleMeshMath.sub(vertices[f.c], vertices[f.a]), 1 / 3))))
        }
        _ = try subtree(Array(faces.indices), vertices, faces, centers, &nodes, &work)
        return nodes
    }

    private static func subtree(_ indices: [Int], _ vertices: [Vector3], _ faces: [TriangleMeshFace],
                                _ centers: [Vector3], _ nodes: inout [TriangleMeshNode], _ work: inout CollisionWork)
        throws(TriangleMeshError) -> Int {
        try TriangleMeshMath.charge(128, &work)
        guard let first = indices.first else { throw .invalidMesh }
        let index = nodes.count
        var bounds = try triangleBounds(faces[first], vertices)
        for i in indices.dropFirst() {
            try TriangleMeshMath.charge(64, &work)
            bounds = try union(bounds, triangleBounds(faces[i], vertices), left: -1, right: -1)
        }
        nodes.append(bounds)
        if indices.count == 1 {
            nodes[index] = TriangleMeshNode(minimum: bounds.minimum, maximum: bounds.maximum, left: -1, right: -1, face: first)
            return index
        }
        let extent = try TriangleMeshMath.sub(bounds.maximum, bounds.minimum)
        let axis = extent.x >= extent.y && extent.x >= extent.z ? 0 : (extent.y >= extent.z ? 1 : 2)
        let sorting = try TriangleMeshMath.collision { () throws(CollisionError) in
            try CollisionWork.product(indices.count, indices.count)
        }
        try TriangleMeshMath.charge(sorting, &work)
        let ordered = indices.sorted {
            let a = TriangleMeshMath.coordinate(centers[$0], axis), b = TriangleMeshMath.coordinate(centers[$1], axis)
            return a == b ? faces[$0].id < faces[$1].id : a < b
        }
        let middle = ordered.count / 2
        let left = try subtree(Array(ordered[..<middle]), vertices, faces, centers, &nodes, &work)
        let right = try subtree(Array(ordered[middle...]), vertices, faces, centers, &nodes, &work)
        nodes[index] = try union(nodes[left], nodes[right], left: left, right: right)
        return index
    }

    static func refit(_ original: [TriangleMeshNode], _ vertices: [Vector3], _ faces: [TriangleMeshFace],
                      _ work: inout CollisionWork) throws(TriangleMeshError) -> [TriangleMeshNode] {
        try TriangleMeshMath.storage(vertices: vertices.count, faces: faces.count, work: &work)
        var nodes = original
        for i in nodes.indices.reversed() {
            try TriangleMeshMath.charge(128, &work)
            let old = nodes[i]
            if old.face >= 0 {
                let b = try triangleBounds(faces[old.face], vertices)
                nodes[i] = TriangleMeshNode(minimum: b.minimum, maximum: b.maximum, left: -1, right: -1, face: old.face)
            } else { nodes[i] = try union(nodes[old.left], nodes[old.right], left: old.left, right: old.right) }
        }
        return nodes
    }
}
