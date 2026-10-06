public struct HierarchicalTriangleMeshQueries: TriangleMeshQuerying, Sendable {
    public init() {}

    private func admit(_ mesh: TriangleMesh, _ policy: CollisionQueryPolicy, _ work: inout CollisionWork)
        throws(TriangleMeshError) {
        try TriangleMeshMath.charge(64, &work)
        try TriangleMeshMath.storage(vertices: mesh.geometry.vertices.count, faces: mesh.geometry.faces.count, work: &work)
        let error = mesh.geometry.approximationError
        guard error <= policy.maximumApproximationError else {
            throw .collision(.approximationExceeded(value: error, maximum: policy.maximumApproximationError))
        }
    }

    public func point(mesh: TriangleMesh, query: Vector3, policy: CollisionQueryPolicy, work: inout CollisionWork)
        throws(TriangleMeshError) -> TriangleMeshPoint {
        try admit(mesh, policy, &work)
        let local = try TriangleMeshMath.core { () throws(CoreError) in try mesh.pose.inverted().transforming(point: query) }
        let g = mesh.geometry
        var distances = [Double](repeating: .infinity, count: g.faces.count), pending = [0]
        var best: TriangleClosestFeature?, bestFace = -1
        while let index = pending.popLast() {
            try TriangleMeshMath.charge(1024, &work)
            let node = mesh.nodes[index]
            if let best {
                let threshold = try TriangleMeshMath.finite((best.distance + policy.lengthTolerance).nextUp)
                if try lowerDistance(local, node) > threshold { continue }
            }
            if node.face < 0 { pending.append(node.right); pending.append(node.left); continue }
            let candidate = try TriangleMeshKernel.closest(local, g.faces[node.face], g.vertices)
            distances[node.face] = candidate.distance
            if let current = best {
                if candidate.distance < current.distance ||
                    (candidate.distance == current.distance && g.faces[node.face].id < g.faces[bestFace].id) {
                    best = candidate; bestFace = node.face
                }
            } else { best = candidate; bestFace = node.face }
        }
        guard let best else { throw .invalidMesh }
        var ties = 0
        for d in distances {
            try TriangleMeshMath.charge(8, &work)
            if !d.isFinite { continue }
            if abs(try TriangleMeshMath.finite(d - best.distance)) <= policy.lengthTolerance { ties += 1 }
        }
        var inside = false
        if g.distancePolicy == .certifiedTetrahedralSolid {
            var definitelyOutside = false, uncertainBoundary = false
            for f in g.faces {
                try TriangleMeshMath.charge(256, &work)
                let n = try TriangleMeshKernel.normal(f, g.vertices)
                let height = try TriangleMeshMath.dot(n, TriangleMeshMath.sub(local, g.vertices[f.a]))
                if height > policy.lengthTolerance { definitelyOutside = true }
                if abs(height) <= policy.lengthTolerance { uncertainBoundary = true }
            }
            if !definitelyOutside, uncertainBoundary, best.distance > 0 { throw .uncertifiedSolid }
            inside = !definitelyOutside
        }
        let signedDistance = inside ? -best.distance : best.distance
        let localNormal: Vector3
        if best.distance == 0 { localNormal = best.normal }
        else {
            let direction = try TriangleMeshMath.unit(TriangleMeshMath.sub(local, best.point))
            localNormal = inside ? try TriangleMeshMath.scale(direction, -1) : direction
        }
        let boundary = try TriangleMeshMath.core { () throws(CoreError) in try mesh.pose.transforming(point: best.point) }
        let normal = try TriangleMeshMath.core { () throws(CoreError) in try mesh.pose.transforming(direction: localNormal) }
        let reconstruction = try TriangleMeshKernel.reconstruct(best.weights, g.faces[bestFace], g.vertices)
        let primal = try TriangleMeshMath.norm(TriangleMeshMath.sub(best.point, reconstruction))
        let balance = try TriangleMeshMath.norm(TriangleMeshMath.sub(TriangleMeshMath.sub(query, boundary),
            TriangleMeshMath.scale(normal, signedDistance)))
        let residual = max(primal, balance)
        try accept(residual, best.weights, normal, policy)
        return TriangleMeshPoint(geometry: g, pose: mesh.pose, boundaryPoint: boundary, normal: normal,
            distance: signedDistance, faceID: g.faces[bestFace].id, feature: best.feature,
            barycentricWeights: best.weights, numericalTieCount: ties, usesFaceNormalAtBoundary: best.distance == 0,
            originalBalanceResidual: residual)
    }

    private func lowerDistance(_ query: Vector3, _ node: TriangleMeshNode) throws(TriangleMeshError) -> Double {
        func delta(_ x: Double, _ lower: Double, _ upper: Double) throws(TriangleMeshError) -> Double {
            if x < lower { return max(0, try TriangleMeshMath.finite((lower - x).nextDown)) }
            if x > upper { return max(0, try TriangleMeshMath.finite((x - upper).nextDown)) }
            return 0
        }
        let v = try TriangleMeshMath.vector(delta(query.x, node.minimum.x, node.maximum.x),
            delta(query.y, node.minimum.y, node.maximum.y), delta(query.z, node.minimum.z, node.maximum.z))
        let x = max(0, try TriangleMeshMath.finite((v.x * v.x).nextDown))
        let y = max(0, try TriangleMeshMath.finite((v.y * v.y).nextDown))
        let z = max(0, try TriangleMeshMath.finite((v.z * v.z).nextDown))
        let xy = max(0, try TriangleMeshMath.finite((x + y).nextDown))
        let sum = max(0, try TriangleMeshMath.finite((xy + z).nextDown))
        return max(0, try TriangleMeshMath.finite(sum.squareRoot().nextDown))
    }

    private func accept(_ residual: Double, _ weights: Vector3, _ normal: Vector3, _ policy: CollisionQueryPolicy)
        throws(TriangleMeshError) {
        guard weights.x >= 0, weights.y >= 0, weights.z >= 0 else { throw .invalidMesh }
        let sumError = abs(try TriangleMeshMath.finite(weights.x + weights.y + weights.z - 1))
        let unitError = abs(try TriangleMeshMath.norm(normal) - 1)
        guard max(sumError, unitError) <= policy.normalTolerance else {
            throw .residualRejected(value: max(sumError, unitError), threshold: policy.normalTolerance)
        }
        guard residual <= policy.lengthTolerance else { throw .residualRejected(value: residual, threshold: policy.lengthTolerance) }
    }

    public func bounds(mesh: TriangleMesh, work: inout CollisionWork) throws(TriangleMeshError) -> CollisionBounds {
        try TriangleMeshMath.charge(2048, &work)
        try TriangleMeshMath.storage(vertices: mesh.geometry.vertices.count, faces: mesh.geometry.faces.count, work: &work)
        let b = mesh.nodes[0], t = mesh.pose.translation
        let m = try TriangleMeshMath.core { () throws(CoreError) in try mesh.pose.rotation.matrix() }
        func interval(_ a: Double, _ c: Double, _ d: Double, _ translation: Double)
            throws(TriangleMeshError) -> (Double, Double) {
            let lowerInputs = [b.minimum.x, b.minimum.y, b.minimum.z]
            let upperInputs = [b.maximum.x, b.maximum.y, b.maximum.z]
            let coefficients = [a, c, d]
            var lower = 0.0, upper = 0.0
            for i in 0..<3 {
                let coefficient = coefficients[i]
                let low = coefficient >= 0 ? lowerInputs[i] : upperInputs[i]
                let high = coefficient >= 0 ? upperInputs[i] : lowerInputs[i]
                let productLower = try TriangleMeshMath.finite((coefficient * low).nextDown)
                let productUpper = try TriangleMeshMath.finite((coefficient * high).nextUp)
                lower = try TriangleMeshMath.finite((lower + productLower).nextDown)
                upper = try TriangleMeshMath.finite((upper + productUpper).nextUp)
            }
            return (try TriangleMeshMath.finite((lower + translation).nextDown),
                    try TriangleMeshMath.finite((upper + translation).nextUp))
        }
        let x = try interval(m.m00, m.m01, m.m02, t.x), y = try interval(m.m10, m.m11, m.m12, t.y)
        let z = try interval(m.m20, m.m21, m.m22, t.z)
        return .finite(minimum: try TriangleMeshMath.vector(x.0, y.0, z.0),
                       maximum: try TriangleMeshMath.vector(x.1, y.1, z.1))
    }

    public func ray(mesh: TriangleMesh, ray: CollisionRay, policy: CollisionQueryPolicy, work: inout CollisionWork)
        throws(TriangleMeshError) -> TriangleMeshRayHit? {
        try admit(mesh, policy, &work)
        let inverse = try TriangleMeshMath.core { () throws(CoreError) in try mesh.pose.inverted() }
        let origin = try TriangleMeshMath.core { () throws(CoreError) in try inverse.transforming(point: ray.origin) }
        let direction = try TriangleMeshMath.core { () throws(CoreError) in try inverse.transforming(direction: ray.direction) }
        let g = mesh.geometry
        var best: TriangleMeshRayCandidate?, distances = [Double](repeating: .infinity, count: g.faces.count)
        for i in g.faces.indices {
            try TriangleMeshMath.charge(2048, &work)
            let f = g.faces[i], n = try TriangleMeshKernel.normal(f, g.vertices)
            let height = try TriangleMeshMath.dot(n, TriangleMeshMath.sub(origin, g.vertices[f.a]))
            let speed = try TriangleMeshMath.dot(n, direction)
            let speedUncertainty = 64 * Double.ulpOfOne
            if abs(speed) <= speedUncertainty {
                let reach = try TriangleMeshMath.finite((abs(speed) + speedUncertainty) * ray.maximumDistance + policy.lengthTolerance)
                if abs(height) > reach { continue }
                let interval = try coplanarInterval(origin, direction, ray.maximumDistance, f, g.vertices)
                if !interval { continue }
                throw .ambiguousRay(faceID: f.id)
            }
            let distance = try TriangleMeshMath.finite(-height / speed)
            if distance < 0 || distance > ray.maximumDistance {
                if distance >= -policy.lengthTolerance,
                   try distance <= TriangleMeshMath.finite(ray.maximumDistance + policy.lengthTolerance) {
                    throw .ambiguousRay(faceID: f.id)
                }
                continue
            }
            let p = try TriangleMeshMath.add(origin, TriangleMeshMath.scale(direction, distance))
            let w = try TriangleMeshKernel.barycentric(p, f, g.vertices)
            let minimum = min(w.x, min(w.y, w.z))
            if minimum < 0 {
                if minimum >= -policy.normalTolerance { throw .ambiguousRay(faceID: f.id) }
                continue
            }
            distances[i] = distance
            let candidate = TriangleMeshRayCandidate(distance: distance, face: i, weights: w)
            if let current = best {
                if distance < current.distance || (distance == current.distance && f.id < g.faces[current.face].id) { best = candidate }
            } else { best = candidate }
        }
        guard let best else { return nil }
        var ties = 0
        for d in distances {
            try TriangleMeshMath.charge(8, &work)
            if !d.isFinite { continue }
            if abs(try TriangleMeshMath.finite(d - best.distance)) <= policy.lengthTolerance { ties += 1 }
        }
        let face = g.faces[best.face]
        let local = try TriangleMeshKernel.reconstruct(best.weights, face, g.vertices)
        let point = try TriangleMeshMath.core { () throws(CoreError) in try mesh.pose.transforming(point: local) }
        let faceNormal = try TriangleMeshKernel.normal(face, g.vertices)
        let normal = try TriangleMeshMath.core { () throws(CoreError) in try mesh.pose.transforming(direction: faceNormal) }
        let original = try TriangleMeshMath.add(ray.origin, TriangleMeshMath.scale(ray.direction, best.distance))
        let residual = try TriangleMeshMath.norm(TriangleMeshMath.sub(point, original))
        try accept(residual, best.weights, normal, policy)
        return TriangleMeshRayHit(geometry: g, pose: mesh.pose, point: point, distance: best.distance,
            orientedFaceNormal: normal, faceID: face.id, feature: TriangleMeshKernel.feature(best.weights, face),
            barycentricWeights: best.weights, numericalTieCount: ties, originalResidual: residual)
    }

    private func coplanarInterval(_ origin: Vector3, _ direction: Vector3, _ maximum: Double,
                                 _ face: TriangleMeshFace, _ vertices: [Vector3]) throws(TriangleMeshError) -> Bool {
        let a = try TriangleMeshKernel.barycentric(origin, face, vertices)
        let b = try TriangleMeshKernel.barycentric(TriangleMeshMath.add(origin, direction), face, vertices)
        let derivative = try TriangleMeshMath.sub(b, a)
        var lower = 0.0, upper = maximum
        for axis in 0..<3 {
            let value = TriangleMeshMath.coordinate(a, axis), change = TriangleMeshMath.coordinate(derivative, axis)
            if change == 0 { if value < 0 { return false } }
            else {
                let root = try TriangleMeshMath.finite(-value / change)
                if change > 0 { lower = max(lower, root) } else { upper = min(upper, root) }
            }
        }
        return lower <= upper
    }

    private func contact(_ sphere: CollisionProxy, _ mesh: TriangleMesh, _ radius: Double,
                         _ policy: CollisionQueryPolicy, _ work: inout CollisionWork)
        throws(TriangleMeshError) -> TriangleMeshSphereContact {
        let p = try point(mesh: mesh, query: sphere.pose.translation, policy: policy, work: &work)
        let normal = try TriangleMeshMath.scale(p.normal, -1)
        let spherePoint = try TriangleMeshMath.sub(sphere.pose.translation, TriangleMeshMath.scale(p.normal, radius))
        let separation = try TriangleMeshMath.finite(p.distance - radius)
        let residual = try TriangleMeshMath.norm(TriangleMeshMath.sub(TriangleMeshMath.sub(p.boundaryPoint, spherePoint),
            TriangleMeshMath.scale(normal, separation)))
        guard residual <= policy.lengthTolerance else { throw .residualRejected(value: residual, threshold: policy.lengthTolerance) }
        return TriangleMeshSphereContact(sphereGeometry: sphere.geometry, spherePose: sphere.pose, meshPoint: p,
            spherePoint: spherePoint, normalFromSphereToMesh: normal, separation: separation,
            approximationError: try TriangleMeshMath.finite(sphere.geometry.approximationError + mesh.geometry.approximationError),
            originalBalanceResidual: residual)
    }

    public func timeOfImpact(sphere: CollisionSweep, mesh: TriangleMeshSweep, durationSeconds: Double,
                             maximumTimeWidthSeconds: Double, policy: CollisionQueryPolicy, work: inout CollisionWork)
        throws(TriangleMeshError) -> TriangleMeshSphereTOI? {
        guard durationSeconds.isFinite, durationSeconds > 0, maximumTimeWidthSeconds.isFinite,
              maximumTimeWidthSeconds > 0 else { throw .collision(.invalidPolicy) }
        try admit(mesh.start, policy, &work)
        try TriangleMeshMath.collision { () throws(CollisionError) in try policy.validate(sphere.start) }
        let g = mesh.start.geometry, s = sphere.start.geometry
        guard s.colliderID != g.colliderID else { throw .collision(.invalidIdentity) }
        guard s.frameID == g.frameID, s.frameRevision == g.frameRevision else { throw .collision(.frameMismatch) }
        guard case .sphere(let nominal) = s.shape else { throw .unsupportedSweep }
        let radius = try TriangleMeshMath.finite(nominal + s.margin)
        let initial = try contact(sphere.start, mesh.start, radius, policy, &work)
        let startIteration = work.iterations
        if initial.separation <= 0 {
            return TriangleMeshSphereTOI(lowerTime: 0, upperTime: 0, lowerSeparation: initial.separation,
                upperContact: initial, initialOverlap: true, iterations: 0)
        }
        let origin = try TriangleMeshMath.core { () throws(CoreError) in
            try mesh.start.pose.inverted().transforming(point: sphere.start.pose.translation)
        }
        let end = try TriangleMeshMath.core { () throws(CoreError) in
            try mesh.end.pose.inverted().transforming(point: sphere.end.pose.translation)
        }
        let velocity = try TriangleMeshMath.sub(end, origin)
        if velocity == .zero { return nil }
        var earliest: Double?, ambiguous: Double?
        for f in g.faces {
            try TriangleMeshMath.charge(8192, &work)
            let n = try TriangleMeshKernel.normal(f, g.vertices)
            let height = try TriangleMeshMath.dot(n, TriangleMeshMath.sub(origin, g.vertices[f.a]))
            let speed = try TriangleMeshMath.dot(n, velocity)
            if speed != 0 {
                for sign in [-1.0, 1.0] {
                    let t = try TriangleMeshMath.finite((sign * radius - height) / speed)
                    if t >= 0, t <= 1 {
                        let center = try TriangleMeshMath.add(origin, TriangleMeshMath.scale(velocity, t))
                        let projected = try TriangleMeshMath.sub(center, TriangleMeshMath.scale(n, sign * radius))
                        let w = try TriangleMeshKernel.barycentric(projected, f, g.vertices)
                        try candidate(TriangleMeshRoot(fraction: t, ambiguous: false),
                            domain: min(w.x, min(w.y, w.z)), origin: origin, velocity: velocity, radius: radius,
                            face: f, vertices: g.vertices, policy: policy, earliest: &earliest, ambiguous: &ambiguous)
                    }
                }
            }
            let indices = [f.a, f.b, f.c]
            for k in 0..<3 {
                let a = g.vertices[indices[k]], b = g.vertices[indices[(k + 1) % 3]]
                let edge = try TriangleMeshMath.sub(b, a), length = try TriangleMeshMath.norm(edge)
                let direction = try TriangleMeshMath.unit(edge), delta = try TriangleMeshMath.sub(origin, a)
                let perpendicular = try TriangleMeshMath.sub(delta, TriangleMeshMath.scale(direction, TriangleMeshMath.dot(delta, direction)))
                let motion = try TriangleMeshMath.sub(velocity, TriangleMeshMath.scale(direction, TriangleMeshMath.dot(velocity, direction)))
                for root in try roots(perpendicular, motion, radius) {
                    guard root.fraction >= 0, root.fraction <= 1 else { continue }
                    let center = try TriangleMeshMath.add(origin, TriangleMeshMath.scale(velocity, root.fraction))
                    let u = try TriangleMeshMath.finite(TriangleMeshMath.dot(TriangleMeshMath.sub(center, a), direction) / length)
                    try candidate(root, domain: min(u, 1 - u), origin: origin, velocity: velocity, radius: radius,
                        face: f, vertices: g.vertices, policy: policy, earliest: &earliest, ambiguous: &ambiguous)
                }
                for root in try roots(delta, velocity, radius) {
                    try candidate(root, domain: 0, origin: origin, velocity: velocity, radius: radius,
                        face: f, vertices: g.vertices, policy: policy, earliest: &earliest, ambiguous: &ambiguous)
                }
            }
        }
        if let uncertainty = ambiguous {
            guard let earliest else { throw .ambiguousSweep }
            if uncertainty <= earliest { throw .ambiguousSweep }
        }
        guard let earliest else { return nil }
        let fractionWidth = try TriangleMeshMath.finite(maximumTimeWidthSeconds / durationSeconds)
        var offset = min(0.5, fractionWidth / 2), upper = earliest
        var upperContact = try contact(TriangleMeshMath.collision { () throws(CollisionError) in try sphere.proxy(at: earliest) },
            mesh.mesh(at: earliest), radius, policy, &work)
        while upperContact.separation > 0 {
            try TriangleMeshMath.iterate(&work)
            guard offset > 0 else { throw .ambiguousSweep }
            upper = min(1, try TriangleMeshMath.finite(earliest + offset))
            guard upper > earliest else { throw .ambiguousSweep }
            upperContact = try contact(TriangleMeshMath.collision { () throws(CollisionError) in try sphere.proxy(at: upper) },
                mesh.mesh(at: upper), radius, policy, &work)
            if upperContact.separation > 0 { offset /= 2 }
        }
        var lower = 0.0, lowerSeparation = initial.separation
        while try TriangleMeshMath.finite((upper - lower) * durationSeconds) > maximumTimeWidthSeconds {
            try TriangleMeshMath.iterate(&work)
            let middle = try TriangleMeshMath.finite(lower + (upper - lower) / 2)
            guard middle > lower, middle < upper else { throw .nonConvergence(iterations: work.iterations - startIteration) }
            let c = try contact(TriangleMeshMath.collision { () throws(CollisionError) in try sphere.proxy(at: middle) },
                mesh.mesh(at: middle), radius, policy, &work)
            if c.separation > 0 {
                guard middle < earliest else { throw .ambiguousSweep }
                lower = middle; lowerSeparation = c.separation
            } else {
                guard middle >= earliest else { throw .ambiguousSweep }
                upper = middle; upperContact = c
            }
        }
        guard lowerSeparation > 0, upperContact.separation <= 0, lower <= earliest, earliest <= upper else { throw .ambiguousSweep }
        return TriangleMeshSphereTOI(lowerTime: try TriangleMeshMath.finite(lower * durationSeconds),
            upperTime: try TriangleMeshMath.finite(upper * durationSeconds), lowerSeparation: lowerSeparation,
            upperContact: upperContact, initialOverlap: false, iterations: work.iterations - startIteration)
    }

    private func candidate(_ root: TriangleMeshRoot, domain: Double, origin: Vector3, velocity: Vector3, radius: Double,
                           face: TriangleMeshFace, vertices: [Vector3], policy: CollisionQueryPolicy,
                           earliest: inout Double?, ambiguous: inout Double?) throws(TriangleMeshError) {
        guard root.fraction >= 0, root.fraction <= 1 else { return }
        if domain < -policy.normalTolerance { return }
        let center = try TriangleMeshMath.add(origin, TriangleMeshMath.scale(velocity, root.fraction))
        let closest = try TriangleMeshKernel.closest(center, face, vertices)
        let residual = try TriangleMeshMath.finite(closest.distance - radius)
        if residual < -policy.lengthTolerance { return }
        guard residual <= policy.lengthTolerance else { throw .residualRejected(value: residual, threshold: policy.lengthTolerance) }
        if domain < 0 || root.ambiguous { ambiguous = min(ambiguous ?? .infinity, root.fraction) }
        else { earliest = min(earliest ?? .infinity, root.fraction) }
    }

    private func roots(_ delta: Vector3, _ velocity: Vector3, _ radius: Double) throws(TriangleMeshError) -> [TriangleMeshRoot] {
        var a = try TriangleMeshMath.dot(velocity, velocity), b = try TriangleMeshMath.dot(delta, velocity)
        var c = try TriangleMeshMath.finite(TriangleMeshMath.dot(delta, delta) - radius * radius)
        if a == 0 { return [] }
        let scale = max(a, max(abs(b), abs(c)))
        a /= scale; b /= scale; c /= scale
        let discriminant = try TriangleMeshMath.finite(b * b - a * c)
        let uncertainty = (abs(b * b) + abs(a * c)) * (64 * Double.ulpOfOne)
        if discriminant < 0 {
            if -discriminant <= uncertainty {
                return [TriangleMeshRoot(fraction: try TriangleMeshMath.finite(-b / a), ambiguous: true)]
            }
            return []
        }
        let squareRoot = discriminant.squareRoot(), q = -(b + (b >= 0 ? squareRoot : -squareRoot))
        if q == 0 { return [TriangleMeshRoot(fraction: try TriangleMeshMath.finite(-b / a), ambiguous: true)] }
        let first = try TriangleMeshMath.finite(q / a), second = try TriangleMeshMath.finite(c / q)
        let ambiguous = discriminant <= uncertainty
        return [TriangleMeshRoot(fraction: min(first, second), ambiguous: ambiguous),
                TriangleMeshRoot(fraction: max(first, second), ambiguous: ambiguous)]
    }
}
