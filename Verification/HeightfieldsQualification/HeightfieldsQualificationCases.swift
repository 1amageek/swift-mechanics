import SwiftMechanics

public enum HeightfieldsQualificationCases {
    private typealias F = HeightfieldsQualificationFixtures

    public static func flatOriginalFeatures() throws {
        let queries: any HeightfieldQuerying = ReferenceHeightfieldQueries()
        var work = try F.work(); let policy = try F.policy()
        let field = try F.field(work: &work); let ref = field.identity.reference
        let face = try queries.closest(field: field, expected: ref, query: Vector3(0.75,0.25,2), policy: policy, work: &work)
        try F.vector(face.boundaryPoint,0.75,0.25,0,"Face projection")
        try F.scalar(face.unsignedDistance,2,"Face distance")
        try F.check(face.face.row == 0 && face.face.column == 0 && face.face.half == 0 && face.feature == .face,"Original face")
        try F.scalar(face.barycentric.first,0.25,"Face first weight")
        try F.scalar(face.barycentric.second,0.5,"Face second weight")
        try F.scalar(face.barycentric.third,0.25,"Face third weight")
        try F.vector(face.normal,0,0,1,"Face toward-query normal")
        let edge = try queries.closest(field: field, expected: ref, query: Vector3(-1,0.25,2), policy: policy, work: &work)
        try F.check(edge.feature == .edge(first:0,second:2) && edge.face.half == 1,"Original boundary edge")
        try F.vector(edge.boundaryPoint,0,0.25,0,"Edge projection")
        try F.scalar(edge.unsignedDistance,5.0.squareRoot(),"Edge distance")
        let vertex = try queries.closest(field: field, expected: ref, query: Vector3(-1,-1,2), policy: policy, work: &work)
        try F.check(vertex.feature == .vertex(index:0) && vertex.face.half == 0 && vertex.exactDistanceTieCount == 2,"Original vertex and order")
        try F.vector(vertex.boundaryPoint,0,0,0,"Vertex point")
        try F.scalar(vertex.unsignedDistance,6.0.squareRoot(),"Vertex distance")
        let seam = try queries.closest(field: field, expected: ref, query: Vector3(0.5,0.5,1), policy: policy, work: &work)
        try F.check(seam.feature == .edge(first:0,second:3) && seam.face.half == 0 && seam.exactDistanceTieCount == 2,"Exact seam tie")
        let below = try queries.closest(field: field, expected: ref, query: Vector3(0.75,0.25,-2), policy: policy, work: &work)
        try F.scalar(below.unsignedDistance,2,"Below remains unsigned")
        try F.vector(below.normal,0,0,-1,"Below toward-query normal")
        try F.vector(below.surfaceNormal,0,0,1,"Original upward normal")
        let zero = try queries.closest(field: field, expected: ref, query: Vector3(0.5,0.5,0), policy: policy, work: &work)
        try F.check(zero.unsignedDistance == 0 && zero.normalConvention == .selectedUpwardFaceAtZeroDistance,"Zero convention")
        try F.check(face.originalResidual <= policy.geometry.lengthTolerance && work.operations > 0,"Original gate and work")
    }

    public static func slopeAndTransform() throws {
        let queries: any HeightfieldQuerying = ReferenceHeightfieldQueries()
        var work = try F.work(); let policy = try F.policy()
        let field = try F.field(heights:[0,1,0,1],motion:.prescribedRigidSnapshots,work:&work)
        let result = try queries.closest(field:field,expected:field.identity.reference,query:Vector3(0,0.25,1),policy:policy,work:&work)
        let root = 2.0.squareRoot()
        try F.vector(result.boundaryPoint,0.5,0.25,0.5,"Slope projection")
        try F.scalar(result.unsignedDistance,0.5.squareRoot(),"Slope distance")
        try F.vector(result.normal,-1/root,0,1/root,"Slope normal")
        try F.check(result.feature == .face && result.face.half == 0,"Slope original face")
        try F.scalar(result.barycentric.first,0.5,"Slope first weight")
        try F.scalar(result.barycentric.second,0.25,"Slope second weight")
        try F.scalar(result.barycentric.third,0.25,"Slope third weight")
        try F.scalar(field.maximumTriangleEdgeMeters,3.0.squareRoot(),"Measured full edge")
        let transform = RigidTransform(rotation:try UnitQuaternion(axis:.unitZ,angle:.pi/2),translation:try Vector3(3,-2,5))
        let moved = try field.moved(to:transform)
        let rotated = try queries.closest(field:moved,expected:moved.identity.reference,query:Vector3(2.75,-2,6),policy:policy,work:&work)
        try F.vector(rotated.boundaryPoint,2.75,-1.5,5.5,"Transformed projection")
        try F.vector(rotated.normal,0,-1/root,1/root,"Transformed normal")
        try F.scalar(rotated.unsignedDistance,0.5.squareRoot(),"Transform distance")
        let bounds = try queries.bounds(field:moved,work:&work)
        guard case .finite(let lower,let upper) = bounds else { throw HeightfieldsQualificationError.assertion("Finite terrain bounds") }
        for point in [try Vector3(3,-2,5),try Vector3(3,-1,6),try Vector3(2,-2,5),try Vector3(2,-1,6)] {
            try F.check(point.x >= lower.x && point.x <= upper.x && point.y >= lower.y && point.y <= upper.y && point.z >= lower.z && point.z <= upper.z,"Original vertex enclosure")
        }
        try F.scalar(lower.x,2,"Bounds lower x"); try F.scalar(upper.z,6,"Bounds upper z")
    }

    public static func diagonalsAndRayOrder() throws {
        let queries: any HeightfieldQuerying = ReferenceHeightfieldQueries()
        var work = try F.work(); let policy = try F.policy()
        for diagonal in [HeightfieldDiagonal.lowerLeftToUpperRight,.lowerRightToUpperLeft] {
            let field = try F.field(heights:[0,0,0,1],diagonal:diagonal,work:&work)
            let ray = try CollisionRay(origin:Vector3(0.5,0.5,2),direction:Vector3(0,0,-1),maximumDistance:2)
            guard let hit = try queries.ray(field:field,expected:field.identity.reference,ray:ray,policy:policy,work:&work) else { throw HeightfieldsQualificationError.assertion("Saddle center hit") }
            let height = diagonal == .lowerLeftToUpperRight ? 0.5 : 0
            try F.scalar(hit.distance,2-height,"Original diagonal height")
            try F.vector(hit.surface.boundaryPoint,0.5,0.5,height,"Original diagonal point")
            try F.check(hit.surface.face.half == 0 && hit.exactParameterTieCount == 2,"Ray exact row-major tie")
        }
        let field = try F.field(work:&work); let ref = field.identity.reference
        for z in [-1.0,1] {
            let ray = try CollisionRay(origin:Vector3(0.75,0.25,z),direction:Vector3(0,0,-z),maximumDistance:1)
            guard let hit = try queries.ray(field:field,expected:ref,ray:ray,policy:policy,work:&work) else { throw HeightfieldsQualificationError.assertion("Two-sided endpoint hit") }
            try F.scalar(hit.distance,1,"Finite endpoint"); try F.check(hit.originalRayResidual <= policy.geometry.lengthTolerance,"Ray original balance")
        }
        let coplanar = try CollisionRay(origin:Vector3(-1,0.25,0),direction:.unitX,maximumDistance:2)
        guard let entry = try queries.ray(field:field,expected:ref,ray:coplanar,policy:policy,work:&work) else { throw HeightfieldsQualificationError.assertion("Coplanar entry") }
        try F.scalar(entry.distance,1,"Coplanar first entry")
        try F.check(entry.surface.feature == .edge(first:0,second:2) && entry.surface.face.half == 1,"Coplanar original edge")
        let origin = try CollisionRay(origin:Vector3(0.5,0.5,0),direction:.unitZ,maximumDistance:0)
        let zero = try queries.ray(field:field,expected:ref,ray:origin,policy:policy,work:&work)
        try F.check(zero?.distance == 0 && zero?.exactParameterTieCount == 2,"Boundary origin and tie")
    }

    public static func rayRejectionsAndAmbiguity() throws {
        let queries: any HeightfieldQuerying = ReferenceHeightfieldQueries()
        var work = try F.work(); let policy = try F.policy()
        let field = try F.field(work:&work); let ref = field.identity.reference
        let misses = [
            try CollisionRay(origin:Vector3(0.25,0.25,1),direction:.unitX,maximumDistance:2),
            try CollisionRay(origin:Vector3(2,2,1),direction:Vector3(0,0,-1),maximumDistance:2),
            try CollisionRay(origin:Vector3(0.25,0.25,2),direction:Vector3(0,0,-1),maximumDistance:1),
            try CollisionRay(origin:Vector3(-1,2,0),direction:.unitX,maximumDistance:3),
            try CollisionRay(origin:Vector3(0.25,0.25,1),direction:.unitZ,maximumDistance:1),
        ]
        for (index,ray) in misses.enumerated() {
            let before = work.operations
            do {
                try F.check(try queries.ray(field:field,expected:ref,ray:ray,policy:policy,work:&work) == nil,"Certified full-face miss")
            } catch HeightfieldError.ambiguousRay {
                throw HeightfieldsQualificationError.assertion("Ambiguous original miss ray index \(index)")
            }
            try F.check(work.operations-before >= 14_336,"Both original faces traversed and certified")
        }
        var bounded = try F.work(operations:10_000)
        try F.refuses(.collision(.resourceLimit(resource:.operations,limit:10_000))) {
            _ = try queries.ray(field:field,expected:ref,ray:misses[0],policy:policy,work:&bounded)
        }
        try F.check(bounded.operations > 7_000,"No partial nil under face budget")
        let nearPlane = try CollisionRay(origin:Vector3(0.25,0.25,5e-11),direction:.unitX,maximumDistance:1)
        try F.refuses(.ambiguousRay) { _ = try queries.ray(field:field,expected:ref,ray:nearPlane,policy:policy,work:&work) }
        let nearEndpoint = try CollisionRay(origin:Vector3(0.25,0.25,1+5e-11),direction:Vector3(0,0,-1),maximumDistance:1)
        try F.refuses(.ambiguousRay) { _ = try queries.ray(field:field,expected:ref,ray:nearEndpoint,policy:policy,work:&work) }
    }

    public static func sphereClearanceAndQuality() throws {
        let queries: any HeightfieldQuerying = ReferenceHeightfieldQueries()
        var work = try F.work(); let policy = try F.policy()
        let field = try F.field(work:&work); let ref = field.identity.reference
        for (z,kind,clearance,boundary,normal) in [
            (2.0,HeightfieldSphereOverlap.Kind.separated,0.75,0.75,1.0),
            (0.5,.surfaceIntersection,-0.75,-0.75,1.0),
            (1.25,.boundaryTouching,0.0,0.0,1.0),
            (-2.0,.separated,0.75,-0.75,-1.0),
        ] {
            let sphere = try F.proxy(center:Vector3(0.75,0.25,z))
            let overlap = try queries.overlap(field:field,expected:ref,sphere:sphere,policy:policy,work:&work)
            try F.check(overlap.kind == kind,"Ball-to-surface classification")
            try F.scalar(overlap.clearance,clearance,"Radius plus margin clearance")
            try F.vector(overlap.surface.boundaryPoint,0.75,0.25,0,"Terrain boundary")
            try F.vector(overlap.sphereBoundaryPoint,0.75,0.25,boundary,"Original sphere boundary")
            try F.vector(overlap.surface.normal,0,0,normal,"Clearance direction")
            try F.check(overlap.originalBalanceResidual <= policy.geometry.lengthTolerance,"Original pair balance")
        }
        let near = try F.proxy(center:Vector3(0.75,0.25,1.25+5e-11))
        try F.refuses(.ambiguousOverlap(clearance:near.pose.translation.z-1.25)) { _ = try queries.overlap(field:field,expected:ref,sphere:near,policy:policy,work:&work) }
        let coarse = try F.field(quality:.approximation(maximumDeviationMeters:0.125),work:&work)
        let coarseSphere = try F.proxy(center:Vector3(0.75,0.25,2),quality:.approximation(maximumDeviationMeters:0.125))
        try F.refuses(.collision(.approximationExceeded(value:0.25,maximum:0.2))) { _ = try queries.overlap(field:coarse,expected:coarse.identity.reference,sphere:coarseSphere,policy:policy,work:&work) }
        let finePolicy = try F.policy(error:0.01)
        try F.refuses(.collision(.approximationExceeded(value:0.125,maximum:0.01))) { _ = try queries.closest(field:coarse,expected:coarse.identity.reference,query:.unitZ,policy:finePolicy,work:&work) }
        let resolution = try F.policy(edge:1)
        try F.refuses(.resolutionExceeded(value:field.maximumTriangleEdgeMeters,maximum:1)) { _ = try queries.closest(field:field,expected:ref,query:.unitZ,policy:resolution,work:&work) }
    }

    public static func refitOriginalLifetime() throws {
        let queries: any HeightfieldQuerying = ReferenceHeightfieldQueries()
        var work = try F.work(); let policy = try F.policy()
        let old = try F.field(motion:.deformingSnapshots,work:&work); let ref = old.identity.reference
        let witness = try queries.closest(field:old,expected:ref,query:Vector3(0.75,0.25,2),policy:policy,work:&work)
        let next = try old.refitted(heights:[1,1,1,1],representation:F.representation(revision:2),geometryRevision:2,work:&work)
        try F.refuses(.staleReference) { _ = try queries.closest(field:next,expected:ref,query:.unitZ,policy:policy,work:&work) }
        let current = try queries.closest(field:next,expected:next.identity.reference,query:Vector3(0.75,0.25,2),policy:policy,work:&work)
        try F.scalar(current.unsignedDistance,1,"Actual refit distance")
        try F.vector(current.boundaryPoint,0.75,0.25,1,"Actual refit vertices")
        try F.check(witness.geometry.heights == [0,0,0,0] && old.identity.heights == [0,0,0,0],"Original witness ownership")
        try F.vector(witness.boundaryPoint,0.75,0.25,0,"Original witness lifetime")
        try F.check(next.identity.reference.source.revision == 2 && next.identity.reference.geometryRevision == 2,"Refit revision")
        try F.refuses(.staleReference) { _ = try old.refitted(heights:[1,1,1,1],representation:F.representation(revision:1),geometryRevision:2,work:&work) }
        try F.refuses(.staleReference) { _ = try old.refitted(heights:[1,1,1,1],representation:F.representation(revision:2,source:"other-grid"),geometryRevision:2,work:&work) }
        try F.refuses(.staleReference) { _ = try old.refitted(heights:[1,1,1,1],representation:F.representation(revision:2),geometryRevision:1,work:&work) }
    }

    public static func admissionAndResourceRefusals() throws {
        let queries: any HeightfieldQuerying = ReferenceHeightfieldQueries()
        var work = try F.work(); let policy = try F.policy()
        let field = try F.field(work:&work); let ref = field.identity.reference
        try F.refuses(.invalidGrid) { _ = try F.field(heights:[0],work:&work) }
        try F.refuses(.invalidGrid) { _ = try F.field(spacingX:0,work:&work) }
        try F.refuses(.invalidGrid) { _ = try F.field(heights:[0,0,0,.nan],work:&work) }
        try F.refuses(.invalidGrid) { _ = try F.field(origin:Vector3(1e20,0,0),work:&work) }
        try F.refuses(.degenerateTriangle(row:0,column:0,half:0)) { _ = try F.field(spacingY:1e-10,work:&work) }
        try F.refuses(.staleReference) { _ = try F.field(sourceRevision:2,expectedSource:1,work:&work) }
        try F.refuses(.forbiddenMotion) { _ = try F.field(motion:.dynamicConcaveBody,work:&work) }
        try F.refuses(.forbiddenMotion) { _ = try field.moved(to:RigidTransform(rotation:.identity,translation:.unitZ)) }
        try F.refuses(.forbiddenMotion) { _ = try field.refitted(heights:[1,1,1,1],representation:F.representation(revision:2),geometryRevision:2,work:&work) }
        try F.refuses(.unsupportedSignedSolid) { _ = try queries.signedSolidDistance(field:field,expected:ref,query:.zero,policy:policy,work:&work) }
        let box = try F.proxy(center:.unitZ,shape:.box(halfExtents:Vector3(1,1,1)))
        try F.refuses(.unsupportedShape) { _ = try queries.overlap(field:field,expected:ref,sphere:box,policy:policy,work:&work) }
        let wrongSphere = try F.proxy(center:.unitZ,frameRevision:2)
        try F.refuses(.frameMismatch) { _ = try queries.overlap(field:field,expected:ref,sphere:wrongSphere,policy:policy,work:&work) }
        let wrongFrame = try HeightfieldReference(colliderID:ref.colliderID,frameID:ref.frameID,frameRevision:2,geometryRevision:1,source:ref.source)
        try F.refuses(.frameMismatch) { _ = try queries.closest(field:field,expected:wrongFrame,query:.unitZ,policy:policy,work:&work) }
        let wrongSource = try HeightfieldReference(colliderID:ref.colliderID,frameID:ref.frameID,frameRevision:1,geometryRevision:1,source:SourceProvenance(source:"original-grid",revision:2))
        try F.refuses(.staleReference) { _ = try queries.closest(field:field,expected:wrongSource,query:.unitZ,policy:policy,work:&work) }
        var operations = try F.work(operations:0)
        try F.refuses(.collision(.resourceLimit(resource:.operations,limit:0))) { _ = try queries.closest(field:field,expected:ref,query:.unitZ,policy:policy,work:&operations) }
        try F.check(operations.operations == 0 && operations.peakScalarStorage == 576,"Failed work receipt")
        var storage = try F.work(storage:0)
        try F.refuses(.collision(.resourceLimit(resource:.scalarStorage,limit:0))) { _ = try queries.bounds(field:field,work:&storage) }
        var records = try F.work(records:0)
        try F.refuses(.collision(.resourceLimit(resource:.records,limit:0))) { _ = try queries.closest(field:field,expected:ref,query:.unitZ,policy:policy,work:&records) }
        try F.check(records.peakScalarStorage == 576 && records.operations == 0,"Capacity receipt preserved")
        let before = work.operations
        _ = try queries.closest(field:field,expected:ref,query:.unitZ,policy:policy,work:&work)
        let middle = work.operations
        _ = try queries.closest(field:field,expected:ref,query:.unitZ,policy:policy,work:&work)
        try F.check(middle > before && work.operations > middle,"Cumulative original work")
    }

    public static func cancelledPaths(field: GridHeightfield, sphere: CollisionProxy) throws {
        let queries: any HeightfieldQuerying = ReferenceHeightfieldQueries()
        var work = try F.work(); let policy = try F.policy(); let ref = field.identity.reference
        let ray = try CollisionRay(origin:.unitZ,direction:Vector3(0,0,-1),maximumDistance:2)
        try F.refuses(.collision(.cancelled)) { _ = try F.field(work:&work) }
        try F.refuses(.collision(.cancelled)) { _ = try queries.closest(field:field,expected:ref,query:.unitZ,policy:policy,work:&work) }
        try F.refuses(.collision(.cancelled)) { _ = try queries.ray(field:field,expected:ref,ray:ray,policy:policy,work:&work) }
        try F.refuses(.collision(.cancelled)) { _ = try queries.overlap(field:field,expected:ref,sphere:sphere,policy:policy,work:&work) }
        try F.refuses(.collision(.cancelled)) { _ = try queries.bounds(field:field,work:&work) }
        try F.refuses(.collision(.cancelled)) { _ = try field.refitted(heights:[1,1,1,1],representation:F.representation(revision:2),geometryRevision:2,work:&work) }
        try F.refuses(.collision(.cancelled)) { _ = try queries.signedSolidDistance(field:field,expected:ref,query:.zero,policy:policy,work:&work) }
        try F.check(work.operations == 0 && work.peakScalarStorage == 0,"Cancelled paths publish no work or result")
    }
}
