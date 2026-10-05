public struct SupportMappedConvexQueries: ConvexCollisionQuerying, Sendable {
    public init() {}

    public func support(proxy: ConvexProxy, direction: Vector3, work: inout CollisionWork)
        throws(ConvexCollisionError) -> ConvexSupport {
        try ConvexMath.storage(vertices: 1, faces: 0, edges: 0, work: &work)
        try ConvexMath.charge(512, &work)
        guard direction != .zero else { throw .invalidShape }
        let unit = try ConvexMath.unit(direction)
        if let adapter = proxy.analyticAdapter {
            let result = try ConvexMath.collision { () throws(CollisionError) in
                try AnalyticCollisionQueries().support(proxy: adapter, direction: unit, work: &work)
            }
            return ConvexSupport(point: result.point, feature: .analytic(result.feature), direction: unit)
        }
        let local = try ConvexMath.core { () throws(CoreError) in
            try proxy.pose.rotation.conjugated().rotating(unit)
        }
        let localUnit = try ConvexMath.unit(local)
        let point: Vector3, feature: ConvexFeature
        switch proxy.geometry.shape {
        case .sphere(let radius):
            point = try ConvexMath.scale(localUnit, radius); feature = .analytic(.sphere)
        case .box(let h):
            let mask = (local.x >= 0 ? 1 : 0) | (local.y >= 0 ? 2 : 0) | (local.z >= 0 ? 4 : 0)
            point = try ConvexMath.vector(local.x >= 0 ? h.x : -h.x,
                local.y >= 0 ? h.y : -h.y, local.z >= 0 ? h.z : -h.z)
            feature = .analytic(.boxVertex(positiveMask: mask))
        case .capsule(let radius, let halfLength):
            let positive = local.z >= 0
            point = try ConvexMath.add(ConvexMath.scale(localUnit, radius),
                ConvexMath.vector(0, 0, positive ? halfLength : -halfLength))
            feature = .capsuleEnd(positive: positive)
        case .cylinder(let radius, let halfHeight):
            let radial = try ConvexMath.vector(local.x, local.y, 0)
            let positive = local.z >= 0
            let rim = radial == .zero ? Vector3.zero : try ConvexMath.scale(ConvexMath.unit(radial), radius)
            point = try ConvexMath.vector(rim.x, rim.y, positive ? halfHeight : -halfHeight)
            feature = radial == .zero ? .cylinderCap(positive: positive) : .cylinderRim(positive: positive)
        case .cone(let radius, let halfHeight):
            let radial = try ConvexMath.vector(local.x, local.y, 0)
            let rim = radial == .zero ? Vector3.zero : try ConvexMath.scale(ConvexMath.unit(radial), radius)
            let base = try ConvexMath.vector(rim.x, rim.y, -halfHeight)
            let apex = try ConvexMath.vector(0, 0, halfHeight)
            if try ConvexMath.dot(local, apex) >= ConvexMath.dot(local, base) {
                point = apex; feature = .coneApex
            } else {
                point = base; feature = radial == .zero ? .coneBase : .coneBaseRim
            }
        case .hull(let vertices):
            guard !vertices.isEmpty else { throw .invalidShape }
            var index = 0, maximum = try ConvexMath.dot(local, vertices[0])
            for i in vertices.indices {
                try ConvexMath.charge(16, &work)
                let value = try ConvexMath.dot(local, vertices[i])
                if value > maximum { index = i; maximum = value }
            }
            point = vertices[index]; feature = .hullVertex(index: index)
        }
        let world = try ConvexMath.core { () throws(CoreError) in try proxy.pose.transforming(point: point) }
        return ConvexSupport(point: try ConvexMath.add(world, ConvexMath.scale(unit, proxy.geometry.margin)),
            feature: feature, direction: unit)
    }

    public func witness(first: CollisionProxy, second: CollisionProxy,
                        policy: CollisionQueryPolicy, work: inout CollisionWork)
        throws(ConvexCollisionError) -> ConvexCollisionWitness {
        try witness(first: ConvexProxy(adapting: first), second: ConvexProxy(adapting: second),
                    policy: policy, work: &work)
    }

    public func witness(first: ConvexProxy, second: ConvexProxy,
                        policy: CollisionQueryPolicy, work: inout CollisionWork)
        throws(ConvexCollisionError) -> ConvexCollisionWitness {
        try ConvexMath.charge(128, &work)
        let pair = try ConvexPairIdentity(first: first.geometry, second: second.geometry)
        for proxy in [first, second] {
            let error = proxy.geometry.approximationError
            guard error <= policy.maximumApproximationError else {
                throw .collision(.approximationExceeded(value: error, maximum: policy.maximumApproximationError))
            }
        }
        try ConvexMath.storage(vertices: 5, faces: 0, edges: 0, work: &work)
        var direction = try ConvexMath.sub(second.pose.translation, first.pose.translation)
        if direction == .zero {
            direction = try ConvexMath.core { () throws(CoreError) in try first.pose.transforming(direction: .unitX) }
        }
        direction = try ConvexMath.unit(direction)
        var vertices = [try vertex(first, second, direction, &work)]
        while true {
            try ConvexMath.iterate(&work)
            let projection = try closest(vertices, &work)
            let distance = try ConvexMath.norm(projection.point)
            if distance > 0 { direction = try ConvexMath.scale(ConvexMath.unit(projection.point), -1) }
            let next = try vertex(first, second, direction, &work)
            let plane = try ConvexMath.dot(direction, next.difference)
            let lower = try ConvexMath.finite(-plane)
            let residual = try ConvexMath.finite(distance - lower)
            guard residual >= -policy.lengthTolerance else {
                throw .residualRejected(value: -residual, threshold: policy.lengthTolerance)
            }
            if distance > 0, lower > 0, residual <= policy.lengthTolerance {
                return try result(pair, first, second, projection, direction, distance,
                    lower, distance, max(0, residual), .regular, policy, &work)
            }
            let touchingInterval = try ConvexMath.finite(distance + max(0, plane))
            if distance <= policy.lengthTolerance, touchingInterval <= policy.lengthTolerance {
                return try result(pair, first, second, projection, direction, 0,
                    -max(0, plane), distance, touchingInterval, .numericalTouching, policy, &work)
            }
            if distance <= policy.lengthTolerance {
                let seed = try interiorSeed(projection.vertices, first, second, policy, &work)
                return try penetration(seed, pair, first, second, policy, &work)
            }
            if projection.vertices.contains(where: { $0.difference == next.difference }) { throw .duplicateSupport }
            guard projection.vertices.count < 4 else { throw .degenerateSimplex }
            vertices = projection.vertices
            vertices.append(next)
        }
    }

    private func vertex(_ a: ConvexProxy, _ b: ConvexProxy, _ direction: Vector3, _ work: inout CollisionWork)
        throws(ConvexCollisionError) -> ConvexSimplexVertex {
        let sa = try support(proxy: a, direction: direction, work: &work)
        let sb = try support(proxy: b, direction: ConvexMath.scale(direction, -1), work: &work)
        return ConvexSimplexVertex(first: sa, second: sb, difference: try ConvexMath.sub(sa.point, sb.point))
    }

    private func closest(_ vertices: [ConvexSimplexVertex], _ work: inout CollisionWork)
        throws(ConvexCollisionError) -> ConvexProjection {
        guard !vertices.isEmpty, vertices.count <= 4 else { throw .degenerateSimplex }
        var best: ConvexProjection?, shortest = Double.infinity
        for mask in 1..<(1 << vertices.count) {
            try ConvexMath.charge(512, &work)
            var face: [ConvexSimplexVertex] = []
            for i in vertices.indices where mask & (1 << i) != 0 { face.append(vertices[i]) }
            guard let candidate = try affine(face), candidate.weights.allSatisfy({ $0 >= 0 }) else { continue }
            let distance = try ConvexMath.norm(candidate.point)
            if distance < shortest { best = candidate; shortest = distance }
        }
        guard let best else { throw .degenerateSimplex }
        return best
    }

    private func affine(_ vertices: [ConvexSimplexVertex]) throws(ConvexCollisionError) -> ConvexProjection? {
        if vertices.count == 1 { return ConvexProjection(vertices: vertices, weights: [1], point: vertices[0].difference) }
        var scale = 0.0
        for v in vertices { scale = max(scale, try ConvexMath.norm(v.difference)) }
        guard scale > 0 else { return nil }
        let p = try ConvexMath.scale(vertices[0].difference, 1 / scale)
        var edges: [Vector3] = []
        for i in 1..<vertices.count {
            edges.append(try ConvexMath.sub(ConvexMath.scale(vertices[i].difference, 1 / scale), p))
        }
        let n = edges.count
        var matrix = [Double](repeating: 0, count: n * (n + 1))
        for i in 0..<n {
            for j in 0..<n { matrix[i * (n + 1) + j] = try ConvexMath.dot(edges[i], edges[j]) }
            matrix[i * (n + 1) + n] = try ConvexMath.finite(-ConvexMath.dot(edges[i], p))
        }
        guard let solution = try solve(matrix, n) else { return nil }
        var weights = [1.0]
        for x in solution { weights[0] = try ConvexMath.finite(weights[0] - x); weights.append(x) }
        var point = Vector3.zero
        for i in vertices.indices { point = try ConvexMath.add(point, ConvexMath.scale(vertices[i].difference, weights[i])) }
        return ConvexProjection(vertices: vertices, weights: weights, point: point)
    }

    private func solve(_ input: [Double], _ n: Int) throws(ConvexCollisionError) -> [Double]? {
        var a = input
        var maximum = 0.0
        for i in 0..<n { for j in 0..<n { maximum = max(maximum, abs(a[i * (n + 1) + j])) } }
        guard maximum > 0 else { return nil }
        let threshold = maximum * (64 * Double.ulpOfOne)
        for k in 0..<n {
            var pivot = k
            for i in k..<n where abs(a[i * (n + 1) + k]) > abs(a[pivot * (n + 1) + k]) { pivot = i }
            guard abs(a[pivot * (n + 1) + k]) > threshold else { return nil }
            if pivot != k { for j in k...n { a.swapAt(k * (n + 1) + j, pivot * (n + 1) + j) } }
            let denominator = a[k * (n + 1) + k]
            for j in k...n { a[k * (n + 1) + j] = try ConvexMath.finite(a[k * (n + 1) + j] / denominator) }
            for i in 0..<n where i != k {
                let factor = a[i * (n + 1) + k]
                for j in k...n {
                    a[i * (n + 1) + j] = try ConvexMath.finite(a[i * (n + 1) + j] - factor * a[k * (n + 1) + j])
                }
            }
        }
        var result: [Double] = []
        for i in 0..<n { result.append(a[i * (n + 1) + n]) }
        return result
    }

    private func interiorSeed(_ initial: [ConvexSimplexVertex], _ a: ConvexProxy, _ b: ConvexProxy,
                              _ policy: CollisionQueryPolicy, _ work: inout CollisionWork)
        throws(ConvexCollisionError) -> [ConvexSimplexVertex] {
        var candidates = initial
        try ConvexMath.storage(vertices: initial.count + 26, faces: 4, edges: 12, work: &work)
        if let seed = try tetrahedron(candidates, policy, &work) { return seed }
        for x in -1...1 { for y in -1...1 { for z in -1...1 where x != 0 || y != 0 || z != 0 {
            try ConvexMath.iterate(&work)
            let direction = try ConvexMath.core { () throws(CoreError) in
                try a.pose.transforming(direction: Vector3(Double(x), Double(y), Double(z)))
            }
            let candidate = try vertex(a, b, direction, &work)
            try ConvexMath.charge(candidates.count * 8, &work)
            if !candidates.contains(where: { $0.difference == candidate.difference }) {
                candidates.append(candidate)
                if let seed = try tetrahedron(candidates, policy, &work) { return seed }
            }
        } } }
        throw .unresolvedInteriorSeed
    }

    private func tetrahedron(_ vertices: [ConvexSimplexVertex], _ policy: CollisionQueryPolicy,
                             _ work: inout CollisionWork) throws(ConvexCollisionError) -> [ConvexSimplexVertex]? {
        guard vertices.count >= 4 else { return nil }
        // Only subsets containing the newest point can be newly feasible.
        let last = vertices.count - 1
        for i in 0..<(last - 2) { for j in (i + 1)..<(last - 1) { for k in (j + 1)..<last {
            try ConvexMath.charge(1024, &work)
            let tetra = [vertices[i], vertices[j], vertices[k], vertices[last]]
            guard let projection = try affine(tetra), projection.weights.allSatisfy({ $0 > 64 * Double.ulpOfOne }),
                  try ConvexMath.norm(projection.point) <= policy.lengthTolerance else { continue }
            let faces = try initialFaces(tetra)
            if faces.allSatisfy({ $0.distance > 0 }) { return tetra }
        } } }
        return nil
    }

    private func face(_ a: Int, _ b: Int, _ c: Int, _ vertices: [ConvexSimplexVertex])
        throws(ConvexCollisionError) -> ConvexPolytopeFace {
        let e1 = try ConvexMath.sub(vertices[b].difference, vertices[a].difference)
        let e2 = try ConvexMath.sub(vertices[c].difference, vertices[a].difference)
        let scale = max(try ConvexMath.norm(e1), try ConvexMath.norm(e2))
        guard scale > 0 else { throw .degenerateSimplex }
        let cross = try ConvexMath.cross(ConvexMath.scale(e1, 1 / scale), ConvexMath.scale(e2, 1 / scale))
        guard try ConvexMath.norm(cross) > 64 * Double.ulpOfOne else { throw .degenerateSimplex }
        let normal = try ConvexMath.unit(cross)
        return ConvexPolytopeFace(a: a, b: b, c: c, normal: normal,
            distance: try ConvexMath.dot(normal, vertices[a].difference))
    }

    private func initialFaces(_ vertices: [ConvexSimplexVertex]) throws(ConvexCollisionError) -> [ConvexPolytopeFace] {
        var faces: [ConvexPolytopeFace] = []
        for indices in [[0, 1, 2, 3], [0, 3, 1, 2], [0, 2, 3, 1], [1, 3, 2, 0]] {
            let raw = try face(indices[0], indices[1], indices[2], vertices)
            let side = try ConvexMath.dot(raw.normal, ConvexMath.sub(vertices[indices[3]].difference,
                vertices[indices[0]].difference))
            guard side != 0 else { throw .degenerateSimplex }
            faces.append(side < 0 ? raw : try face(raw.a, raw.c, raw.b, vertices))
        }
        return faces
    }

    private func penetration(_ seed: [ConvexSimplexVertex], _ pair: ConvexPairIdentity,
                             _ a: ConvexProxy, _ b: ConvexProxy, _ policy: CollisionQueryPolicy,
                             _ work: inout CollisionWork) throws(ConvexCollisionError) -> ConvexCollisionWitness {
        var vertices = seed, faces = try initialFaces(seed)
        while true {
            try ConvexMath.iterate(&work)
            let futureVertices = try ConvexMath.collision { () throws(CollisionError) in
                try CollisionWork.sum(vertices.count, 1)
            }
            try ConvexMath.storage(vertices: futureVertices, faces: faces.count,
                                   edges: try ConvexMath.collision { () throws(CollisionError) in
                                       try CollisionWork.product(faces.count, 3)
                                   }, work: &work)
            try validatePolytope(vertices, faces, policy, &work)
            let selectionWork = try ConvexMath.collision { () throws(CollisionError) in
                try CollisionWork.product(faces.count, 8)
            }
            try ConvexMath.charge(selectionWork, &work)
            guard let nearest = faces.min(by: { $0.distance < $1.distance }) else { throw .invalidPolytope }
            let triangle = [vertices[nearest.a], vertices[nearest.b], vertices[nearest.c]]
            guard let projection = try affine(triangle), projection.weights.allSatisfy({ $0 >= 0 }) else {
                throw .degenerateSimplex
            }
            let primal = try ConvexMath.norm(ConvexMath.sub(projection.point,
                ConvexMath.scale(nearest.normal, nearest.distance)))
            guard primal <= policy.lengthTolerance else {
                throw .residualRejected(value: primal, threshold: policy.lengthTolerance)
            }
            let next = try vertex(a, b, nearest.normal, &work)
            let upper = try ConvexMath.dot(nearest.normal, next.difference)
            let interval = try ConvexMath.finite(upper - nearest.distance)
            guard interval >= -policy.lengthTolerance else { throw .invalidPolytope }
            if interval <= policy.lengthTolerance {
                var ties = 0
                for f in faces {
                    try ConvexMath.charge(8, &work)
                    if abs(try ConvexMath.finite(f.distance - nearest.distance)) <= policy.lengthTolerance { ties += 1 }
                }
                let degeneracy: ConvexWitnessDegeneracy = ties > 1 ? .equidistantPolytopeFaces(count: ties) : .regular
                return try result(pair, a, b, projection, nearest.normal, -nearest.distance,
                    -upper, -nearest.distance, max(0, interval), degeneracy, policy, &work)
            }
            let duplicateWork = try ConvexMath.collision { () throws(CollisionError) in
                try CollisionWork.product(vertices.count, 8)
            }
            try ConvexMath.charge(duplicateWork, &work)
            if vertices.contains(where: { $0.difference == next.difference }) { throw .duplicateSupport }
            var horizon: [ConvexHorizonEdge] = [], retained: [ConvexPolytopeFace] = []
            for f in faces {
                try ConvexMath.charge(64, &work)
                if try ConvexMath.dot(f.normal, ConvexMath.sub(next.difference, vertices[f.a].difference)) > 0 {
                    for edge in edges(f) { try toggle(edge, &horizon, &work) }
                } else { retained.append(f) }
            }
            guard horizon.count >= 3 else { throw .invalidPolytope }
            let futureFaces = try ConvexMath.collision { () throws(CollisionError) in
                try CollisionWork.sum(retained.count, horizon.count)
            }
            try ConvexMath.storage(vertices: futureVertices, faces: max(faces.count, futureFaces),
                edges: horizon.count, work: &work)
            let index = vertices.count
            vertices.append(next)
            for edge in horizon {
                try ConvexMath.charge(256, &work)
                let added = try face(edge.start, edge.end, index, vertices)
                guard added.distance > 0 else { throw .invalidPolytope }
                retained.append(added)
            }
            faces = retained
        }
    }

    private func edges(_ face: ConvexPolytopeFace) -> [ConvexHorizonEdge] {
        [ConvexHorizonEdge(start: face.a, end: face.b), ConvexHorizonEdge(start: face.b, end: face.c),
         ConvexHorizonEdge(start: face.c, end: face.a)]
    }

    private func toggle(_ edge: ConvexHorizonEdge, _ horizon: inout [ConvexHorizonEdge],
                        _ work: inout CollisionWork) throws(ConvexCollisionError) {
        for i in horizon.indices {
            try ConvexMath.charge(8, &work)
            if horizon[i] == edge { throw .invalidPolytope }
            if horizon[i].start == edge.end, horizon[i].end == edge.start { horizon.remove(at: i); return }
        }
        horizon.append(edge)
    }

    private func validatePolytope(_ vertices: [ConvexSimplexVertex], _ faces: [ConvexPolytopeFace],
                                  _ policy: CollisionQueryPolicy, _ work: inout CollisionWork)
        throws(ConvexCollisionError) {
        guard faces.count >= 4 else { throw .invalidPolytope }
        for f in faces {
            guard f.distance > 0 else { throw .invalidPolytope }
            for v in vertices {
                try ConvexMath.charge(32, &work)
                guard try ConvexMath.dot(f.normal, ConvexMath.sub(v.difference, vertices[f.a].difference))
                    <= policy.lengthTolerance else { throw .invalidPolytope }
            }
            for edge in edges(f) {
                var matches = 0, duplicates = 0
                for g in faces { for other in edges(g) {
                    try ConvexMath.charge(8, &work)
                    if edge.start == other.end, edge.end == other.start { matches += 1 }
                    if edge == other { duplicates += 1 }
                } }
                guard matches == 1, duplicates == 1 else { throw .invalidPolytope }
            }
        }
    }

    private func result(_ pair: ConvexPairIdentity, _ a: ConvexProxy, _ b: ConvexProxy,
                        _ projection: ConvexProjection, _ normal: Vector3, _ separation: Double,
                        _ lower: Double, _ upper: Double, _ interval: Double,
                        _ degeneracy: ConvexWitnessDegeneracy,
                        _ policy: CollisionQueryPolicy, _ work: inout CollisionWork)
        throws(ConvexCollisionError) -> ConvexCollisionWitness {
        try ConvexMath.charge(1024, &work)
        var pa = Vector3.zero, pb = Vector3.zero, sum = 0.0
        var supports: [ConvexSupportWeight] = []
        for i in projection.vertices.indices {
            let weight = projection.weights[i], vertex = projection.vertices[i]
            guard weight.isFinite, weight >= 0 else { throw .degenerateSimplex }
            sum = try ConvexMath.finite(sum + weight)
            pa = try ConvexMath.add(pa, ConvexMath.scale(vertex.first.point, weight))
            pb = try ConvexMath.add(pb, ConvexMath.scale(vertex.second.point, weight))
            supports.append(ConvexSupportWeight(first: vertex.first, second: vertex.second, weight: weight))
        }
        let weightResidual = abs(sum - 1), normalResidual = abs(try ConvexMath.norm(normal) - 1)
        guard max(weightResidual, normalResidual) <= policy.normalTolerance else {
            throw .residualRejected(value: max(weightResidual, normalResidual), threshold: policy.normalTolerance)
        }
        let difference = try ConvexMath.sub(pa, pb)
        let balance = try ConvexMath.norm(ConvexMath.add(difference, ConvexMath.scale(normal, separation)))
        var simplex = try ConvexMath.norm(ConvexMath.sub(difference, projection.point))
        if separation >= 0, try ConvexMath.norm(projection.point) > 0 {
            let axis = try ConvexMath.unit(projection.point)
            for v in projection.vertices {
                let stationarity = try ConvexMath.dot(axis, ConvexMath.sub(v.difference, projection.point))
                simplex = max(simplex, abs(stationarity))
            }
        }
        let maximum = max(balance, max(simplex, interval))
        guard maximum <= policy.lengthTolerance else {
            throw .residualRejected(value: maximum, threshold: policy.lengthTolerance)
        }
        guard try ConvexMath.finite(lower - upper) <= policy.lengthTolerance else { throw .invalidPolytope }
        return ConvexCollisionWitness(pair: pair, poseA: a.pose, poseB: b.pose, pointA: pa, pointB: pb,
            normal: normal, separation: separation, supports: supports, degeneracy: degeneracy,
            approximationError: try ConvexMath.finite(a.geometry.approximationError + b.geometry.approximationError),
            originalBalanceResidual: balance, simplexResidual: simplex, supportIntervalResidual: interval,
            separationLowerBound: lower, separationUpperBound: upper, iterations: work.iterations)
    }
}
