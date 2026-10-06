public struct ReferenceHeightfieldQueries: HeightfieldQuerying, Sendable {
    public init() {}

    public func closest(field: GridHeightfield, expected: HeightfieldReference, query: Vector3,
                        policy: HeightfieldQueryPolicy, work: inout CollisionWork) throws(HeightfieldError) -> HeightfieldPoint {
        try validate(field,expected:expected,policy:policy,work:&work)
        var best: HeightfieldPoint?
        var ties = 0
        for row in 0..<(field.identity.rows-1) { for column in 0..<(field.identity.columns-1) { for half in 0..<2 {
            try HeightfieldMath.charge(1024,&work)
            let triangle = try field.triangle(row:row,column:column,half:half)
            let projection = try triangle.closest(query,policy:policy.geometry,work:&work)
            if let current = best {
                if projection.distance < current.unsignedDistance {
                    best = try result(field,triangle:triangle,query:query,projection:projection,policy:policy.geometry)
                    ties = 1
                } else if projection.distance == current.unsignedDistance {
                    ties = try HeightfieldMath.sum(ties,1)
                }
            } else {
                best = try result(field,triangle:triangle,query:query,projection:projection,policy:policy.geometry)
                ties = 1
            }
        } } }
        guard let selected = best else { throw .invalidGrid }
        return withTies(selected,ties)
    }

    public func ray(field: GridHeightfield, expected: HeightfieldReference, ray: CollisionRay,
                    policy: HeightfieldQueryPolicy, work: inout CollisionWork) throws(HeightfieldError) -> HeightfieldRayHit? {
        try validate(field,expected:expected,policy:policy,work:&work)
        var best: HeightfieldRayHit?
        var ties = 0
        for row in 0..<(field.identity.rows-1) { for column in 0..<(field.identity.columns-1) { for half in 0..<2 {
            try HeightfieldMath.charge(1024,&work)
            let triangle = try field.triangle(row:row,column:column,half:half)
            guard let distance = try HeightfieldTriangleRay.intersection(triangle,ray:ray,policy:policy.geometry,work:&work) else { continue }
            let point = try HeightfieldMath.add(ray.origin,HeightfieldMath.scale(ray.direction,distance))
            let projection = try triangle.closest(point,policy:policy.geometry,work:&work)
            try HeightfieldMath.accept(projection.distance,policy.geometry.lengthTolerance)
            let residual = try HeightfieldMath.norm(HeightfieldMath.sub(projection.point,point))
            try HeightfieldMath.accept(residual,policy.geometry.lengthTolerance)
            let candidate = HeightfieldRayHit(distance:distance,
                surface:try result(field,triangle:triangle,query:point,projection:projection,policy:policy.geometry),
                exactParameterTieCount:1,originalRayResidual:residual)
            if let current = best {
                if distance < current.distance { best = candidate; ties = 1 }
                else if distance == current.distance { ties = try HeightfieldMath.sum(ties,1) }
            } else { best = candidate; ties = 1 }
        } } }
        guard let selected = best else { return nil }
        return HeightfieldRayHit(distance:selected.distance,surface:selected.surface,
            exactParameterTieCount:ties,originalRayResidual:selected.originalRayResidual)
    }

    public func overlap(field: GridHeightfield, expected: HeightfieldReference, sphere: CollisionProxy,
                        policy: HeightfieldQueryPolicy, work: inout CollisionWork) throws(HeightfieldError) -> HeightfieldSphereOverlap {
        try validate(field,expected:expected,policy:policy,work:&work)
        try chargeKey(sphere.geometry.frameID.key,work:&work)
        guard sphere.geometry.frameID == field.identity.reference.frameID,
              sphere.geometry.frameRevision == field.identity.reference.frameRevision else { throw .frameMismatch }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Non-sphere overlap geometry is unavailable.
        // Public overlap consumers must fail until original shape-to-grid feature equations are qualified.
        guard case .sphere(let radius) = sphere.geometry.shape else { throw .unsupportedShape }
        do { try policy.geometry.validate(sphere) } catch { throw .collision(error) }
        let error = try HeightfieldMath.finite(field.identity.approximationError+sphere.geometry.approximationError)
        guard error <= policy.geometry.maximumApproximationError else {
            throw .collision(.approximationExceeded(value:error,maximum:policy.geometry.maximumApproximationError))
        }
        let effectiveRadius = try HeightfieldMath.finite(radius+sphere.geometry.margin)
        let surface = try closest(field:field,expected:expected,query:sphere.pose.translation,policy:policy,work:&work)
        let clearance = try HeightfieldMath.finite(surface.unsignedDistance-effectiveRadius)
        let kind: HeightfieldSphereOverlap.Kind
        if clearance == 0 { kind = .boundaryTouching }
        else if abs(clearance) <= policy.geometry.lengthTolerance { throw .ambiguousOverlap(clearance:clearance) }
        else { kind = clearance < 0 ? .surfaceIntersection : .separated }
        let boundary = try HeightfieldMath.sub(sphere.pose.translation,HeightfieldMath.scale(surface.normal,effectiveRadius))
        let residual = try HeightfieldMath.norm(HeightfieldMath.sub(HeightfieldMath.sub(boundary,surface.boundaryPoint),
            HeightfieldMath.scale(surface.normal,clearance)))
        try HeightfieldMath.accept(residual,policy.geometry.lengthTolerance)
        let radiusResidual = abs(try HeightfieldMath.norm(HeightfieldMath.sub(boundary,sphere.pose.translation))-effectiveRadius)
        try HeightfieldMath.accept(radiusResidual,policy.geometry.lengthTolerance)
        return HeightfieldSphereOverlap(kind:kind,surface:surface,sphere:sphere.geometry,spherePose:sphere.pose,
            sphereBoundaryPoint:boundary,clearance:clearance,approximationError:error,
            originalBalanceResidual:max(residual,radiusResidual))
    }

    public func bounds(field: GridHeightfield, work: inout CollisionWork) throws(HeightfieldError) -> CollisionBounds {
        try HeightfieldMath.reserve(vertexCount:field.vertices.count,work:&work)
        guard let first = field.vertices.first else { throw .invalidGrid }
        let initial = try HeightfieldMath.point(field.pose,first)
        var lx = initial.x, ly = initial.y, lz = initial.z
        var ux = initial.x, uy = initial.y, uz = initial.z
        for vertex in field.vertices {
            try HeightfieldMath.charge(256,&work)
            let point = try HeightfieldMath.point(field.pose,vertex)
            lx = min(lx,point.x); ly = min(ly,point.y); lz = min(lz,point.z)
            ux = max(ux,point.x); uy = max(uy,point.y); uz = max(uz,point.z)
        }
        return .finite(minimum:try HeightfieldMath.vector(lx.nextDown,ly.nextDown,lz.nextDown),
                       maximum:try HeightfieldMath.vector(ux.nextUp,uy.nextUp,uz.nextUp))
    }

    // FIXME(INCOMPLETE_IMPLEMENTATION): A finite terrain surface has no certified closed solid.
    // Signed-distance consumers must fail until independently validated volume/inside semantics exist.
    public func signedSolidDistance(field: GridHeightfield, expected: HeightfieldReference, query: Vector3,
                                    policy: HeightfieldQueryPolicy, work: inout CollisionWork) throws(HeightfieldError) -> HeightfieldPoint {
        try validate(field,expected:expected,policy:policy,work:&work)
        throw .unsupportedSignedSolid
    }

    private func validate(_ field: GridHeightfield, expected: HeightfieldReference,
                          policy: HeightfieldQueryPolicy, work: inout CollisionWork) throws(HeightfieldError) {
        try HeightfieldMath.reserve(vertexCount:field.vertices.count,work:&work)
        let actual = field.identity.reference
        for key in [actual.colliderID.key,expected.colliderID.key,actual.frameID.key,expected.frameID.key,
                    actual.source.source,expected.source.source] { try chargeKey(key,work:&work) }
        guard actual.frameID == expected.frameID, actual.frameRevision == expected.frameRevision else { throw .frameMismatch }
        guard actual == expected else { throw .staleReference }
        guard field.identity.approximationError <= policy.geometry.maximumApproximationError else {
            throw .collision(.approximationExceeded(value:field.identity.approximationError,maximum:policy.geometry.maximumApproximationError))
        }
        guard field.maximumTriangleEdgeMeters <= policy.maximumTriangleEdgeMeters else {
            throw .resolutionExceeded(value:field.maximumTriangleEdgeMeters,maximum:policy.maximumTriangleEdgeMeters)
        }
    }

    private func result(_ field: GridHeightfield, triangle: HeightfieldTriangle, query: Vector3,
                        projection: HeightfieldTriangleProjection, policy: CollisionQueryPolicy) throws(HeightfieldError) -> HeightfieldPoint {
        let normal: Vector3
        let convention: HeightfieldNormalConvention
        if projection.distance == 0 { normal = triangle.normal; convention = .selectedUpwardFaceAtZeroDistance }
        else {
            normal = try HeightfieldMath.unit(HeightfieldMath.sub(query,projection.point))
            convention = .towardQuery
        }
        try HeightfieldMath.accept(abs(try HeightfieldMath.norm(normal)-1),policy.normalTolerance)
        let residual = max(projection.residual,try HeightfieldMath.norm(HeightfieldMath.sub(
            HeightfieldMath.sub(query,projection.point),HeightfieldMath.scale(normal,projection.distance))))
        try HeightfieldMath.accept(residual,policy.lengthTolerance)
        return HeightfieldPoint(geometry:field.identity,pose:field.pose,query:query,boundaryPoint:projection.point,
            unsignedDistance:projection.distance,normal:normal,surfaceNormal:triangle.normal,normalConvention:convention,
            face:triangle.face,feature:projection.feature,barycentric:projection.barycentric,
            exactDistanceTieCount:1,originalResidual:residual)
    }

    private func withTies(_ selected: HeightfieldPoint, _ count: Int) -> HeightfieldPoint {
        HeightfieldPoint(geometry:selected.geometry,pose:selected.pose,query:selected.query,boundaryPoint:selected.boundaryPoint,
            unsignedDistance:selected.unsignedDistance,normal:selected.normal,surfaceNormal:selected.surfaceNormal,
            normalConvention:selected.normalConvention,face:selected.face,feature:selected.feature,
            barycentric:selected.barycentric,exactDistanceTieCount:count,originalResidual:selected.originalResidual)
    }

    private func chargeKey(_ key: String, work: inout CollisionWork) throws(HeightfieldError) {
        for _ in key.utf8 { try HeightfieldMath.charge(4,&work) }
    }
}
