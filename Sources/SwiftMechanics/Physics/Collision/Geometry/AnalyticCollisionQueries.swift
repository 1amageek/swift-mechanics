
public struct AnalyticCollisionQueries: CollisionGeometryQuerying, Sendable {
    public init() {}

    public func witness(first a: CollisionProxy, second b: CollisionProxy, policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionWitness {
        try work.requireStorage(256); try work.requireRecords(1); try work.charge(4096)
        try policy.validate(a); try policy.validate(b)
        let pair = try CollisionPairIdentity(first: a.geometry, second: b.geometry)
        let raw: (Vector3, Vector3, Vector3, Double, CollisionFeature, CollisionFeature, CollisionDegeneracy)
        switch (a.geometry.shape, b.geometry.shape) {
        case (.sphere(let ra), .sphere(let rb)):
            let delta = try sub(b.pose.translation, a.pose.translation), distance = try magnitude(delta)
            let n = distance == 0 ? try rotate(a.pose, .unitX) : try normalize(delta)
            raw = (try add(a.pose.translation, scale(n, ra)), try sub(b.pose.translation, scale(n, rb)), n,
                   try collisionFinite(distance-ra-rb), .sphere, .sphere, distance == 0 ? .coincidentSphereCenters : .regular)
        case (.sphere(let radius), .box(let extents)):
            let local = try inversePoint(b.pose, a.pose.translation)
            let result = try boxPoint(local, half: extents, tolerance: policy.lengthTolerance)
            let n = try scale(rotate(b.pose, result.1), -1)
            raw = (try add(a.pose.translation, scale(n, radius)), try transform(b.pose, result.0), n,
                   try collisionFinite(result.2-radius), .sphere, result.3, result.4)
        case (.sphere(let radius), .halfSpace):
            let nout = try rotate(b.pose, .unitZ), h = try dot(nout, sub(a.pose.translation, b.pose.translation))
            let n = try scale(nout, -1)
            raw = (try add(a.pose.translation, scale(n, radius)), try sub(a.pose.translation, scale(nout,h)), n,
                   try collisionFinite(h-radius), .sphere, .halfSpace, .regular)
        case (.box, .halfSpace):
            let nout = try rotate(b.pose, .unitZ), n = try scale(nout,-1)
            let supported = try nominalSupport(proxy: a, direction: n)
            let h = try dot(nout, sub(supported.point,b.pose.translation))
            raw = (supported.point, try sub(supported.point,scale(nout,h)), n, h, supported.feature, .halfSpace, .regular)
        case (.box, .sphere), (.halfSpace, .sphere), (.halfSpace, .box):
            let reversed = try witness(first: b, second: a, policy: policy, work: &work)
            return CollisionWitness(pair: pair, poseA: a.pose, poseB: b.pose, pointA: reversed.pointB, pointB: reversed.pointA,
                normal: try scale(reversed.normal,-1), separation: reversed.separation,
                featureA: reversed.featureB, featureB: reversed.featureA, degeneracy: reversed.degeneracy,
                approximationError: reversed.approximationError, originalBalanceResidual: reversed.originalBalanceResidual)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Other declared shape pairs are deferred. Witness consumers
        // receive a typed failure until original geometric balance and feature tests establish support.
        default: throw .unsupportedPair
        }
        let pa = try add(raw.0,scale(raw.2,a.geometry.margin))
        let pb = try sub(raw.1,scale(raw.2,b.geometry.margin))
        let separation = try collisionFinite(raw.3-a.geometry.margin-b.geometry.margin)
        let difference = try sub(pb,pa)
        let balance = try magnitude(sub(difference,scale(raw.2,separation)))
        let projectedResidual = abs(try dot(raw.2,difference)-separation)
        let normalResidual = abs(try magnitude(raw.2)-1)
        guard normalResidual <= policy.normalTolerance else { throw .geometricResidual(value: normalResidual, threshold: policy.normalTolerance) }
        let residual = max(balance,projectedResidual)
        guard residual <= policy.lengthTolerance else { throw .geometricResidual(value: residual, threshold: policy.lengthTolerance) }
        return CollisionWitness(pair: pair, poseA: a.pose, poseB: b.pose, pointA: pa, pointB: pb, normal: raw.2, separation: separation,
            featureA: raw.4, featureB: raw.5, degeneracy: raw.6,
            approximationError: try collisionFinite(a.geometry.approximationError+b.geometry.approximationError), originalBalanceResidual: residual)
    }

    public func support(proxy: CollisionProxy, direction: Vector3, work: inout CollisionWork) throws(CollisionError) -> CollisionSupport {
        try work.requireStorage(128); try work.requireRecords(1); try work.charge(1024)
        guard direction != .zero else { throw .invalidShape }
        let n = try normalize(direction), base = try nominalSupport(proxy: proxy,direction: n)
        return CollisionSupport(point: try add(base.point,scale(n,proxy.geometry.margin)), feature: base.feature)
    }

    public func point(proxy: CollisionProxy, query: Vector3, policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionPointResult {
        try work.requireStorage(128); try work.requireRecords(1); try work.charge(2048); try policy.validate(proxy)
        let local = try inversePoint(proxy.pose,query)
        let raw: (Vector3,Vector3,Double,CollisionFeature,CollisionDegeneracy)
        switch proxy.geometry.shape {
        case .sphere(let radius):
            let distance = try magnitude(local), n = distance == 0 ? Vector3.unitX : try normalize(local)
            let effective = try collisionFinite(radius+proxy.geometry.margin)
            raw = (try scale(n,effective),n,try collisionFinite(distance-effective),.sphere,distance == 0 ? .coincidentSphereCenters : .regular)
        case .box(let half):
            // FIXME(INCOMPLETE_IMPLEMENTATION): Rounded-box point queries are deferred. Public point
            // consumers must fail until exact inflated-boundary distance and feature tests are verified.
            guard proxy.geometry.margin == 0 else { throw .unsupportedQuery }
            raw = try boxPoint(local,half: half,tolerance: policy.lengthTolerance)
        case .halfSpace:
            raw = (try vector(local.x,local.y,proxy.geometry.margin),.unitZ,try collisionFinite(local.z-proxy.geometry.margin),.halfSpace,.regular)
        }
        let boundary = try transform(proxy.pose,raw.0), outward = try rotate(proxy.pose,raw.1)
        let residual = try magnitude(sub(sub(query,boundary),scale(outward,raw.2)))
        guard residual <= policy.lengthTolerance else { throw .geometricResidual(value: residual, threshold: policy.lengthTolerance) }
        return CollisionPointResult(geometry: proxy.geometry,boundaryPoint: boundary,outwardNormal: outward,
            signedDistance: raw.2,feature: raw.3,degeneracy: raw.4)
    }

    public func ray(proxy: CollisionProxy, ray: CollisionRay, policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionRayHit? {
        try work.requireStorage(192); try work.charge(4096); try policy.validate(proxy)
        let o = try inversePoint(proxy.pose,ray.origin), d = try rotateInverse(proxy.pose,ray.direction)
        let initial = try point(proxy: proxy,query: ray.origin,policy: policy,work: &work)
        let distance: Double
        if abs(initial.signedDistance) <= policy.lengthTolerance { distance = 0 }
        else {
            switch proxy.geometry.shape {
            case .sphere(let radius):
                let effective = try collisionFinite(radius+proxy.geometry.margin)
                let a = try dot(d,d), b = try dot(o,d), c = try collisionFinite(dot(o,o)-effective*effective)
                let discriminant = try collisionFinite(b*b-a*c)
                if discriminant < 0 { return nil }
                let root = discriminant.squareRoot()
                let lower = try collisionFinite((-b-root)/a), upper = try collisionFinite((-b+root)/a)
                distance = lower >= 0 ? lower : upper
            case .box(let half):
                // FIXME(INCOMPLETE_IMPLEMENTATION): Rounded-box ray queries are deferred. Public ray
                // consumers must fail until original inflated-boundary intersection tests are verified.
                guard proxy.geometry.margin == 0 else { throw .unsupportedQuery }
                var lower = -Double.infinity, upper = Double.infinity
                for axis in 0..<3 {
                    let origin = component(o,axis), direction = component(d,axis), extent = component(half,axis)
                    if direction == 0 {
                        if origin < -extent || origin > extent { return nil }
                    } else {
                        let a = try collisionFinite((-extent-origin)/direction), b = try collisionFinite((extent-origin)/direction)
                        lower = max(lower,min(a,b)); upper = min(upper,max(a,b))
                        if lower > upper { return nil }
                    }
                }
                distance = try collisionFinite(lower >= 0 ? lower : upper)
            case .halfSpace:
                if d.z == 0 { return nil }
                distance = try collisionFinite((proxy.geometry.margin-o.z)/d.z)
            }
        }
        guard distance >= 0, distance <= ray.maximumDistance else { return nil }
        try work.requireRecords(1)
        let hit = try add(ray.origin,scale(ray.direction,distance))
        let result = try point(proxy: proxy,query: hit,policy: policy,work: &work)
        guard abs(result.signedDistance) <= policy.lengthTolerance else { throw .geometricResidual(value: abs(result.signedDistance),threshold: policy.lengthTolerance) }
        return CollisionRayHit(geometry: proxy.geometry,distance: distance,point: hit,outwardNormal: result.outwardNormal,feature: result.feature)
    }

    public func bounds(proxy: CollisionProxy, work: inout CollisionWork) throws(CollisionError) -> CollisionBounds {
        try work.requireStorage(128); try work.charge(1024)
        let extents: Vector3
        switch proxy.geometry.shape {
        case .sphere(let radius):
            let r = try collisionFinite((radius+proxy.geometry.margin).nextUp)
            extents = try vector(r,r,r)
        case .box(let half):
            let r = try collisionCore { () throws(CoreError) in try proxy.pose.rotation.matrix() }
            // Each positive product and sum rounds outward before world addition.
            func extent(_ a: Double,_ b: Double,_ c: Double) throws(CollisionError) -> Double {
                let first = try collisionFinite((abs(a)*half.x).nextUp)
                let second = try collisionFinite((abs(b)*half.y).nextUp)
                let third = try collisionFinite((abs(c)*half.z).nextUp)
                let total = try collisionFinite((first+second).nextUp)
                return try collisionFinite(((total+third).nextUp+proxy.geometry.margin).nextUp)
            }
            extents = try vector(extent(r.m00,r.m01,r.m02),extent(r.m10,r.m11,r.m12),extent(r.m20,r.m21,r.m22))
        case .halfSpace: return .unbounded
        }
        let c = proxy.pose.translation
        let lower = try vector((c.x-extents.x).nextDown,(c.y-extents.y).nextDown,(c.z-extents.z).nextDown)
        let upper = try vector((c.x+extents.x).nextUp,(c.y+extents.y).nextUp,(c.z+extents.z).nextUp)
        return .finite(minimum: lower,maximum: upper)
    }

    private func nominalSupport(proxy: CollisionProxy,direction: Vector3) throws(CollisionError) -> CollisionSupport {
        let local = try rotateInverse(proxy.pose,direction)
        switch proxy.geometry.shape {
        case .sphere(let radius):
            return CollisionSupport(point: try transform(proxy.pose,scale(normalize(local),radius)),feature: .sphere)
        case .box(let h):
            let mask = (local.x >= 0 ? 1 : 0) | (local.y >= 0 ? 2 : 0) | (local.z >= 0 ? 4 : 0)
            let p = try vector(local.x >= 0 ? h.x : -h.x,local.y >= 0 ? h.y : -h.y,local.z >= 0 ? h.z : -h.z)
            return CollisionSupport(point: try transform(proxy.pose,p),feature: .boxVertex(positiveMask: mask))
        case .halfSpace: throw .unsupportedQuery
        }
    }

    private func boxPoint(_ p: Vector3,half h: Vector3,tolerance: Double) throws(CollisionError) -> (Vector3,Vector3,Double,CollisionFeature,CollisionDegeneracy) {
        let q = try vector(max(-h.x,min(h.x,p.x)),max(-h.y,min(h.y,p.y)),max(-h.z,min(h.z,p.z)))
        let delta = try sub(p,q), distance = try magnitude(delta)
        if distance > 0 {
            let mask = (abs(abs(q.x)-h.x) <= tolerance ? 1 : 0) | (abs(abs(q.y)-h.y) <= tolerance ? 2 : 0) | (abs(abs(q.z)-h.z) <= tolerance ? 4 : 0)
            let signs = (p.x >= 0 ? 1 : 0) | (p.y >= 0 ? 2 : 0) | (p.z >= 0 ? 4 : 0)
            return (q,try normalize(delta),distance,.boxBoundary(axisMask: mask,positiveMask: signs & mask),.regular)
        }
        let gx = h.x-abs(p.x), gy = h.y-abs(p.y), gz = h.z-abs(p.z)
        let axis = gx <= gy && gx <= gz ? 0 : (gy <= gz ? 1 : 2)
        let gap = axis == 0 ? gx : (axis == 1 ? gy : gz)
        let positive = component(p,axis) >= 0
        let n = try vector(axis == 0 ? (positive ? 1 : -1) : 0,axis == 1 ? (positive ? 1 : -1) : 0,axis == 2 ? (positive ? 1 : -1) : 0)
        let boundary = try add(p,scale(n,gap))
        let tie = (axis != 0 && gx == gap) || (axis != 1 && gy == gap) || (axis != 2 && gz == gap)
        let boundaryMask = (abs(abs(boundary.x)-h.x) <= tolerance ? 1 : 0) | (abs(abs(boundary.y)-h.y) <= tolerance ? 2 : 0) | (abs(abs(boundary.z)-h.z) <= tolerance ? 4 : 0)
        let signs = (boundary.x >= 0 ? 1 : 0) | (boundary.y >= 0 ? 2 : 0) | (boundary.z >= 0 ? 4 : 0)
        let feature: CollisionFeature = gap == 0 && boundaryMask.nonzeroBitCount > 1 ?
            .boxBoundary(axisMask:boundaryMask,positiveMask:signs & boundaryMask) : .boxFace(axis:axis,positive:positive)
        return (boundary,n,-gap,feature,tie ? .interiorFaceTie : .regular)
    }

    private func component(_ v: Vector3,_ axis: Int) -> Double { axis == 0 ? v.x : (axis == 1 ? v.y : v.z) }
    private func vector(_ x: Double,_ y: Double,_ z: Double) throws(CollisionError) -> Vector3 { try collisionCore { () throws(CoreError) in try Vector3(x,y,z) } }
    private func add(_ a: Vector3,_ b: Vector3) throws(CollisionError) -> Vector3 { try collisionCore { () throws(CoreError) in try a.adding(b) } }
    private func sub(_ a: Vector3,_ b: Vector3) throws(CollisionError) -> Vector3 { try collisionCore { () throws(CoreError) in try a.subtracting(b) } }
    private func scale(_ a: Vector3,_ b: Double) throws(CollisionError) -> Vector3 { try collisionCore { () throws(CoreError) in try a.scaled(by: b) } }
    private func dot(_ a: Vector3,_ b: Vector3) throws(CollisionError) -> Double { try collisionCore { () throws(CoreError) in try a.dot(b) } }
    private func magnitude(_ a: Vector3) throws(CollisionError) -> Double { try collisionCore { () throws(CoreError) in try a.magnitude() } }
    private func normalize(_ a: Vector3) throws(CollisionError) -> Vector3 { try collisionCore { () throws(CoreError) in try a.normalized() } }
    private func transform(_ t: RigidTransform,_ p: Vector3) throws(CollisionError) -> Vector3 { try collisionCore { () throws(CoreError) in try t.transforming(point:p) } }
    private func rotate(_ t: RigidTransform,_ p: Vector3) throws(CollisionError) -> Vector3 { try collisionCore { () throws(CoreError) in try t.transforming(direction:p) } }
    private func rotateInverse(_ t: RigidTransform,_ p: Vector3) throws(CollisionError) -> Vector3 { try collisionCore { () throws(CoreError) in try t.rotation.conjugated().rotating(p) } }
    private func inversePoint(_ t: RigidTransform,_ p: Vector3) throws(CollisionError) -> Vector3 { try collisionCore { () throws(CoreError) in try t.inverted().transforming(point:p) } }
}
