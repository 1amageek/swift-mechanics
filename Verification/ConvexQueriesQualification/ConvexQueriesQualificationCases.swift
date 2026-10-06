import SwiftMechanics

public enum ConvexQueriesQualificationCases {
    public static func originalSupportMaps() throws {
        let query: any ConvexCollisionQuerying = SupportMappedConvexQueries()
        var work = try ConvexQueriesQualificationFixtures.work()
        let d = try Vector3(3,4,0)
        let sphere = try ConvexProxy(adapting: ConvexQueriesQualificationFixtures.analytic("sphere", shape: .sphere(radius:2), margin:0.25))
        let sphereSupport = try query.support(proxy:sphere,direction:d,work:&work)
        try ConvexQueriesQualificationFixtures.vector(sphereSupport.point,Vector3(1.35,1.8,0),"Adapted sphere support and margin")
        try ConvexQueriesQualificationFixtures.check(sphereSupport.feature == .analytic(.sphere),"Original sphere feature")
        let box = try ConvexProxy(adapting: ConvexQueriesQualificationFixtures.analytic("box",shape:.box(halfExtents:Vector3(1,2,3))))
        let boxSupport = try query.support(proxy:box,direction:d,work:&work)
        try ConvexQueriesQualificationFixtures.vector(boxSupport.point,Vector3(1,2,3),"Adapted box extrema")
        try ConvexQueriesQualificationFixtures.check(boxSupport.feature == .analytic(.boxVertex(positiveMask:7)),"Box original vertex and zero-axis tie")
        for (shape, point, feature) in [
            (ConvexShape.capsule(radius:2,halfLength:3),try Vector3(1.2,1.6,3),ConvexFeature.capsuleEnd(positive:true)),
            (.cylinder(radius:2,halfHeight:3),try Vector3(1.2,1.6,3),.cylinderRim(positive:true)),
            (.cone(radius:2,halfHeight:3),try Vector3(1.2,1.6,-3),.coneBaseRim)
        ] {
            let proxy = try ConvexQueriesQualificationFixtures.proxy("primitive",shape:shape,work:&work)
            let support = try query.support(proxy:proxy,direction:d,work:&work)
            try ConvexQueriesQualificationFixtures.vector(support.point,point,"Analytic primitive radial extremum")
            try ConvexQueriesQualificationFixtures.check(support.feature == feature,"Primitive original supporting feature")
            try ConvexQueriesQualificationFixtures.scalar(support.point.dot(support.direction),
                ConvexQueriesQualificationFixtures.supportValue(proxy,support.direction),"Closed-form primitive maximum")
        }
        let cylinder = try ConvexQueriesQualificationFixtures.proxy("cylinder",shape:.cylinder(radius:2,halfHeight:3),work:&work)
        let cap = try query.support(proxy:cylinder,direction:.unitZ,work:&work)
        try ConvexQueriesQualificationFixtures.vector(cap.point,Vector3(0,0,3),"Actual disk-center support")
        try ConvexQueriesQualificationFixtures.check(cap.feature == .cylinderCap(positive:true),"Axial cap feature")
        let rounded = try ConvexQueriesQualificationFixtures.proxy("rounded-cylinder",shape:.cylinder(radius:2,halfHeight:3),margin:0.25,work:&work)
        let roundedSupport = try query.support(proxy:rounded,direction:.unitX,work:&work)
        try ConvexQueriesQualificationFixtures.vector(roundedSupport.point,Vector3(2.25,0,3),"New proxy spherical margin and axial tie")
        let cone = try ConvexQueriesQualificationFixtures.proxy("cone",shape:.cone(radius:2,halfHeight:1),work:&work)
        let apex = try query.support(proxy:cone,direction:Vector3(1,0,1),work:&work)
        try ConvexQueriesQualificationFixtures.vector(apex.point,.unitZ,"Cone support equality chooses apex")
        try ConvexQueriesQualificationFixtures.check(apex.feature == .coneApex,"Cone apex tie feature")
        let base = try query.support(proxy:cone,direction:Vector3(0,0,-1),work:&work)
        try ConvexQueriesQualificationFixtures.vector(base.point,Vector3(0,0,-1),"Cone base center")
        try ConvexQueriesQualificationFixtures.check(base.feature == .coneBase,"Original base feature")
        let hull = try ConvexQueriesQualificationFixtures.proxy("hull",shape:.hull(vertices:ConvexQueriesQualificationFixtures.cube()),work:&work)
        let hullSupport = try query.support(proxy:hull,direction:.unitX,work:&work)
        try ConvexQueriesQualificationFixtures.vector(hullSupport.point,Vector3(1,-1,-1),"Original hull max-dot vertex")
        try ConvexQueriesQualificationFixtures.check(hullSupport.feature == .hullVertex(index:1),"Hull first-index tie")
        let reduced = try ConvexQueriesQualificationFixtures.proxy("zero-segment",shape:.capsule(radius:2,halfLength:0),work:&work)
        try ConvexQueriesQualificationFixtures.vector(query.support(proxy:reduced,direction:d,work:&work).point,
                                                     Vector3(1.2,1.6,0),"Zero-length capsule is actual sphere")
    }

    public static func adaptedSeparationAndReversal() throws {
        let query: any ConvexCollisionQuerying = SupportMappedConvexQueries()
        var work = try ConvexQueriesQualificationFixtures.work()
        let a = try ConvexQueriesQualificationFixtures.analytic("a",shape:.sphere(radius:1),margin:0.1)
        let b = try ConvexQueriesQualificationFixtures.analytic("b",shape:.sphere(radius:0.5),position:Vector3(3,0,0),margin:0.2)
        let ca = try ConvexProxy(adapting:a), cb = try ConvexProxy(adapting:b)
        let w = try query.witness(first:a,second:b,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        try ConvexQueriesQualificationFixtures.certificate(w,first:ca,second:cb,expected:1.2)
        try ConvexQueriesQualificationFixtures.vector(w.pointA,Vector3(1.1,0,0),"Analytic closest first point")
        try ConvexQueriesQualificationFixtures.vector(w.pointB,Vector3(2.3,0,0),"Analytic closest second point")
        try ConvexQueriesQualificationFixtures.vector(w.normal,.unitX,"Positive-gap normal")
        let previous = work.iterations
        let reverse = try query.witness(first:cb,second:ca,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        try ConvexQueriesQualificationFixtures.certificate(reverse,first:cb,second:ca,expected:1.2)
        try ConvexQueriesQualificationFixtures.vector(reverse.pointA,w.pointB,"Reversed first point")
        try ConvexQueriesQualificationFixtures.vector(reverse.pointB,w.pointA,"Reversed second point")
        try ConvexQueriesQualificationFixtures.vector(reverse.normal,Vector3(-1,0,0),"Reversed normal")
        try ConvexQueriesQualificationFixtures.check(reverse.iterations > previous,"Cumulative original work")
    }

    public static func primitiveAndHullSeparation() throws {
        let query: any ConvexCollisionQuerying = SupportMappedConvexQueries()
        for (shape, gap, endpoint) in [(ConvexShape.capsule(radius:0.5,halfLength:1),2.25,1.5),
                                     (.cylinder(radius:1,halfHeight:1),2.75,1.0),
                                     (.cone(radius:1,halfHeight:1),2.75,1.0)] {
            var work = try ConvexQueriesQualificationFixtures.work()
            let a = try ConvexQueriesQualificationFixtures.proxy("primitive",shape:shape,work:&work)
            let b = try ConvexQueriesQualificationFixtures.proxy("sphere",shape:.sphere(radius:0.25),position:Vector3(0,0,4),work:&work)
            let w = try query.witness(first:a,second:b,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
            try ConvexQueriesQualificationFixtures.certificate(w,first:a,second:b,expected:gap)
            try ConvexQueriesQualificationFixtures.vector(w.pointA,Vector3(0,0,endpoint),"Primitive axial point")
            try ConvexQueriesQualificationFixtures.vector(w.pointB,Vector3(0,0,3.75),"Sphere axial point")
            try ConvexQueriesQualificationFixtures.vector(w.normal,.unitZ,"Axial separation normal")
        }
        var work = try ConvexQueriesQualificationFixtures.work()
        let hull = try ConvexQueriesQualificationFixtures.proxy("hull",shape:.hull(vertices:ConvexQueriesQualificationFixtures.cube()),work:&work)
        let box = try ConvexQueriesQualificationFixtures.proxy("box",shape:.box(halfExtents:Vector3(1,1,1)),position:Vector3(3,0,0),work:&work)
        let w = try query.witness(first:hull,second:box,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        try ConvexQueriesQualificationFixtures.certificate(w,first:hull,second:box,expected:1)
        try ConvexQueriesQualificationFixtures.scalar(w.pointA.x,1,"Hull original boundary")
        try ConvexQueriesQualificationFixtures.scalar(w.pointB.x,2,"Box original boundary")
        try ConvexQueriesQualificationFixtures.vector(w.normal,.unitX,"Hull separating normal")
    }

    public static func originalBoxPenetration() throws {
        var work = try ConvexQueriesQualificationFixtures.work()
        let a = try ConvexQueriesQualificationFixtures.proxy("box-a",shape:.box(halfExtents:Vector3(1,1,1)),work:&work)
        let b = try ConvexQueriesQualificationFixtures.proxy("box-b",shape:.box(halfExtents:Vector3(1,1,1)),position:Vector3(1.5,0.125,0.25),work:&work)
        let query: any ConvexCollisionQuerying = SupportMappedConvexQueries()
        let w = try query.witness(first:a,second:b,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        try ConvexQueriesQualificationFixtures.certificate(w,first:a,second:b,expected:-0.5)
        try ConvexQueriesQualificationFixtures.vector(w.normal,.unitX,"Unique box penetration direction")
        try ConvexQueriesQualificationFixtures.scalar(w.pointA.x,1,"First EPA original face")
        try ConvexQueriesQualificationFixtures.scalar(w.pointB.x,0.5,"Second EPA original face")
        try ConvexQueriesQualificationFixtures.check(w.pointA.y >= -0.875-2.2e-8 && w.pointA.y <= 1+2.2e-8 &&
            w.pointA.z >= -0.75-2.2e-8 && w.pointA.z <= 1+2.2e-8,"Original overlapping face range")
        try ConvexQueriesQualificationFixtures.check(w.supports.count >= 2,"Actual weighted EPA supports")
    }

    public static func primitiveAndHullPenetration() throws {
        let query: any ConvexCollisionQuerying = SupportMappedConvexQueries()
        for (shape, center, axis) in [
            (ConvexShape.hull(vertices:try ConvexQueriesQualificationFixtures.cube()),try Vector3(1.5,0.125,0.25),Vector3.unitX),
            (.cylinder(radius:1,halfHeight:1),try Vector3(0,0,1.5),.unitZ),
            (.cone(radius:1,halfHeight:1),try Vector3(0,0,1.5),.unitZ),
            (.capsule(radius:0.5,halfLength:1),try Vector3(0,0,2),.unitZ)
        ] {
            var work = try ConvexQueriesQualificationFixtures.work()
            let a = try ConvexQueriesQualificationFixtures.proxy("primitive",shape:shape,work:&work)
            let b = try ConvexQueriesQualificationFixtures.proxy("box",shape:.box(halfExtents:Vector3(1,1,1)),position:center,work:&work)
            let w = try query.witness(first:a,second:b,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
            try ConvexQueriesQualificationFixtures.certificate(w,first:a,second:b,expected:-0.5)
            try ConvexQueriesQualificationFixtures.vector(w.normal,axis,"Independent EPA primitive depth direction")
        }
    }

    public static func touchingAndCoincidentBoxes() throws {
        let query: any ConvexCollisionQuerying = SupportMappedConvexQueries()
        var work = try ConvexQueriesQualificationFixtures.work()
        let a = try ConvexQueriesQualificationFixtures.proxy("a",shape:.sphere(radius:1),work:&work)
        let b = try ConvexQueriesQualificationFixtures.proxy("b",shape:.sphere(radius:1),position:Vector3(2,0,0),work:&work)
        let touch = try query.witness(first:a,second:b,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        try ConvexQueriesQualificationFixtures.certificate(touch,first:a,second:b,expected:0)
        try ConvexQueriesQualificationFixtures.check(touch.degeneracy == .numericalTouching,"Support-certified contact band")
        try ConvexQueriesQualificationFixtures.vector(touch.pointA,.unitX,"Original touching point")
        let boxA = try ConvexQueriesQualificationFixtures.proxy("box-a",shape:.box(halfExtents:Vector3(1,1,1)),work:&work)
        let boxB = try ConvexQueriesQualificationFixtures.proxy("box-b",shape:.box(halfExtents:Vector3(1,1,1)),work:&work)
        let coincidence = try query.witness(first:boxA,second:boxB,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        try ConvexQueriesQualificationFixtures.certificate(coincidence,first:boxA,second:boxB,expected:-2)
        guard case .equidistantPolytopeFaces(let count) = coincidence.degeneracy else {
            throw ConvexQueriesQualificationError.assertion("Coincident polytope face tie not retained")
        }
        try ConvexQueriesQualificationFixtures.check(count > 1,"Current polytope tie count")
    }

    public static func rigidCovarianceAndSnapshot() throws {
        let query: any ConvexCollisionQuerying = SupportMappedConvexQueries()
        var work = try ConvexQueriesQualificationFixtures.work()
        let a = try ConvexQueriesQualificationFixtures.proxy("sphere-a",shape:.sphere(radius:1),work:&work)
        let b = try ConvexQueriesQualificationFixtures.proxy("sphere-b",shape:.sphere(radius:0.5),position:Vector3(3,0,0),work:&work)
        let gap = 1.5
        let original = try query.witness(first:a,second:b,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        try ConvexQueriesQualificationFixtures.certificate(original,first:a,second:b,expected:gap)
        try ConvexQueriesQualificationFixtures.vector(original.pointA,.unitX,"Independent first spherical boundary")
        try ConvexQueriesQualificationFixtures.vector(original.pointB,Vector3(2.5,0,0),"Independent second spherical boundary")
        let transform = RigidTransform(rotation:try UnitQuaternion(axis:Vector3(1,2,3),angle:0.7),translation:try Vector3(3,-2,1))
        let movedA = try a.moved(to:transform.composed(with:a.pose)), movedB = try b.moved(to:transform.composed(with:b.pose))
        let moved = try query.witness(first:movedA,second:movedB,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        try ConvexQueriesQualificationFixtures.certificate(moved,first:movedA,second:movedB,expected:gap)
        try ConvexQueriesQualificationFixtures.vector(moved.pointA,transform.transforming(point:original.pointA),"First rigid covariance")
        try ConvexQueriesQualificationFixtures.vector(moved.pointB,transform.transforming(point:original.pointB),"Second rigid covariance")
        try ConvexQueriesQualificationFixtures.vector(moved.normal,transform.transforming(direction:original.normal),"Normal covariance")
        try ConvexQueriesQualificationFixtures.check(movedA.geometry == a.geometry && original.poseA == a.pose,"Immutable moved snapshot authority")
        let cylinder = try ConvexQueriesQualificationFixtures.proxy("cylinder",shape:.cylinder(radius:1,halfHeight:2),work:&work)
        let direction = try Vector3(3,4,2)
        let support = try query.support(proxy:cylinder,direction:direction,work:&work)
        let movedCylinder = cylinder.moved(to:transform)
        let transformedSupport = try query.support(proxy:movedCylinder,direction:transform.transforming(direction:direction),work:&work)
        try ConvexQueriesQualificationFixtures.vector(transformedSupport.point,transform.transforming(point:support.point),"Primitive support covariance")
        try ConvexQueriesQualificationFixtures.check(transformedSupport.feature == support.feature,"Original moved support feature")
    }

    public static func identitySourceAndAdmission() throws {
        var work = try ConvexQueriesQualificationFixtures.work()
        for shape in [ConvexShape.sphere(radius:0),.box(halfExtents:try Vector3(1,0,1)),
                      .capsule(radius:1,halfLength:-1),.cylinder(radius:1,halfHeight:0),.cone(radius:.nan,halfHeight:1)] {
            try ConvexQueriesQualificationFixtures.refuses(.invalidShape) {
                _ = try ConvexQueriesQualificationFixtures.proxy("bad",shape:shape,work:&work)
            }
        }
        let plane = try [Vector3(0,0,0),Vector3(1,0,0),Vector3(0,1,0),Vector3(1,1,0)]
        try ConvexQueriesQualificationFixtures.refuses(.degenerateSimplex) {
            _ = try ConvexQueriesQualificationFixtures.proxy("plane",shape:.hull(vertices:plane),work:&work)
        }
        try ConvexQueriesQualificationFixtures.refuses(.collision(.staleGeometry)) {
            _ = try ConvexQueriesQualificationFixtures.proxy("stale",shape:.sphere(radius:1),sourceRevision:2,work:&work)
        }
        try ConvexQueriesQualificationFixtures.refuses(.unsupportedShape) {
            _ = try ConvexProxy(adapting:ConvexQueriesQualificationFixtures.analytic("plane",shape:.halfSpace))
        }
        let query: any ConvexCollisionQuerying = SupportMappedConvexQueries()
        let a = try ConvexQueriesQualificationFixtures.proxy("a",shape:.sphere(radius:1),work:&work)
        let wrongFrame = try ConvexQueriesQualificationFixtures.proxy("b",shape:.sphere(radius:1),frameRevision:2,work:&work)
        try ConvexQueriesQualificationFixtures.refuses(.collision(.frameMismatch)) {
            _ = try query.witness(first:a,second:wrongFrame,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        }
        let otherFrame = try ConvexQueriesQualificationFixtures.proxy("other",shape:.sphere(radius:1),frame:"other-frame",work:&work)
        try ConvexQueriesQualificationFixtures.refuses(.collision(.frameMismatch)) {
            _ = try query.witness(first:a,second:otherFrame,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        }
        try ConvexQueriesQualificationFixtures.refuses(.collision(.invalidIdentity)) {
            _ = try query.witness(first:a,second:a,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        }
        try ConvexQueriesQualificationFixtures.refuses(.invalidShape) {
            _ = try query.support(proxy:a,direction:.zero,work:&work)
        }
        let coarse = try ConvexQueriesQualificationFixtures.proxy("coarse",shape:.sphere(radius:1),quality:.approximation(maximumDeviationMeters:0.2),work:&work)
        try ConvexQueriesQualificationFixtures.refuses(.collision(.approximationExceeded(value:0.2,maximum:0.1))) {
            _ = try query.witness(first:a,second:coarse,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        }
        let first = try ConvexQueriesQualificationFixtures.proxy("source-a",shape:.sphere(radius:1),sourceRevision:3,expectedSource:3,
            geometryRevision:7,quality:.approximation(maximumDeviationMeters:0.03),work:&work)
        let second = try ConvexQueriesQualificationFixtures.proxy("source-b",shape:.sphere(radius:1),position:Vector3(3,0,0),
            sourceRevision:5,expectedSource:5,geometryRevision:9,quality:.approximation(maximumDeviationMeters:0.04),work:&work)
        let w = try query.witness(first:first,second:second,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        try ConvexQueriesQualificationFixtures.certificate(w,first:first,second:second,expected:1)
        try ConvexQueriesQualificationFixtures.scalar(w.approximationError,0.07,"Original approximation error sum")
        try ConvexQueriesQualificationFixtures.check(w.pair.first.representation.provenance.revision == 3 &&
            w.pair.second.representation.provenance.revision == 5 && w.pair.first.geometryRevision == 7 &&
            w.pair.second.geometryRevision == 9,"Original source and geometry revisions")
    }

    public static func boundedWorkAndIterationRefusals() throws {
        var work = try ConvexQueriesQualificationFixtures.work()
        let a = try ConvexQueriesQualificationFixtures.proxy("a",shape:.sphere(radius:1),work:&work)
        let b = try ConvexQueriesQualificationFixtures.proxy("b",shape:.sphere(radius:1),position:Vector3(1.5,0,0),work:&work)
        let query: any ConvexCollisionQuerying = SupportMappedConvexQueries()
        var noOperations = try ConvexQueriesQualificationFixtures.work(operations:0)
        try ConvexQueriesQualificationFixtures.refuses(.collision(.resourceLimit(resource:.operations,limit:0))) {
            _ = try query.witness(first:a,second:b,policy:ConvexQueriesQualificationFixtures.policy(),work:&noOperations)
        }
        try ConvexQueriesQualificationFixtures.check(noOperations.operations == 0,"No fabricated partial work success")
        var noStorage = try ConvexQueriesQualificationFixtures.work(storage:0)
        try ConvexQueriesQualificationFixtures.refuses(.collision(.resourceLimit(resource:.scalarStorage,limit:0))) {
            _ = try query.support(proxy:a,direction:.unitX,work:&noStorage)
        }
        var noRecords = try ConvexQueriesQualificationFixtures.work(records:0)
        try ConvexQueriesQualificationFixtures.refuses(.collision(.resourceLimit(resource:.records,limit:0))) {
            _ = try query.support(proxy:a,direction:.unitX,work:&noRecords)
        }
        try ConvexQueriesQualificationFixtures.check(noRecords.peakScalarStorage == 560 && noRecords.operations == 0,
                                                     "Actual original support reservation ordering")
        var noIterations = try ConvexQueriesQualificationFixtures.work(iterations:0)
        try ConvexQueriesQualificationFixtures.refuses(.nonConvergence(iterations:0)) {
            _ = try query.witness(first:a,second:b,policy:ConvexQueriesQualificationFixtures.policy(),work:&noIterations)
        }
        var oneIteration = try ConvexQueriesQualificationFixtures.work(iterations:1)
        try ConvexQueriesQualificationFixtures.refuses(.nonConvergence(iterations:1)) {
            _ = try query.witness(first:a,second:b,policy:ConvexQueriesQualificationFixtures.policy(),work:&oneIteration)
        }
        try ConvexQueriesQualificationFixtures.check(oneIteration.iterations == 1 && oneIteration.operations > 0,
                                                     "Nonconvergence preserves consumed work")
    }

    public static func cancelledPaths(first: ConvexProxy, second: ConvexProxy,
                                      analyticFirst: CollisionProxy, analyticSecond: CollisionProxy) throws {
        let query: any ConvexCollisionQuerying = SupportMappedConvexQueries()
        var work = try ConvexQueriesQualificationFixtures.work()
        try ConvexQueriesQualificationFixtures.refuses(.collision(.cancelled)) {
            _ = try ConvexQueriesQualificationFixtures.proxy("cancelled",shape:.sphere(radius:1),work:&work)
        }
        try ConvexQueriesQualificationFixtures.refuses(.collision(.cancelled)) {
            _ = try query.support(proxy:first,direction:.unitX,work:&work)
        }
        try ConvexQueriesQualificationFixtures.refuses(.collision(.cancelled)) {
            _ = try query.witness(first:first,second:second,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        }
        try ConvexQueriesQualificationFixtures.refuses(.collision(.cancelled)) {
            _ = try query.witness(first:analyticFirst,second:analyticSecond,policy:ConvexQueriesQualificationFixtures.policy(),work:&work)
        }
        try ConvexQueriesQualificationFixtures.check(work.operations == 0 && work.peakScalarStorage == 0 && work.iterations == 0,
                                                     "Cancelled paths preserve original work")
    }
}
