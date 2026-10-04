import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct GeometryTests {
    @Test func spherePairMarginsCoincidenceAndCommonTransform() throws {
        let queries: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        var work = try CollisionFixtures.work()
        let policy = try CollisionFixtures.policy()
        let a = try CollisionFixtures.proxy("a",shape:.sphere(radius:1),margin:0.1)
        let b = try CollisionFixtures.proxy("b",shape:.sphere(radius:0.5),position:Vector3(3,0,0),margin:0.2)
        let w = try queries.witness(first:a,second:b,policy:policy,work:&work)
        #expect(CollisionFixtures.close(w.separation,1.2))
        #expect(try CollisionFixtures.vectorClose(w.pointA,Vector3(1.1,0,0)))
        #expect(try CollisionFixtures.vectorClose(w.pointB,Vector3(2.3,0,0)))
        #expect(w.normal == .unitX)
        #expect(CollisionFixtures.close(try w.normal.dot(w.pointB.subtracting(w.pointA)),w.separation))
        let transform = RigidTransform(rotation:try UnitQuaternion(axis:Vector3(1,2,3),angle:1.1),translation:try Vector3(3,-2,1))
        let ar = a.moved(to:try transform.composed(with:a.pose)), br = b.moved(to:try transform.composed(with:b.pose))
        let wr = try queries.witness(first:ar,second:br,policy:policy,work:&work)
        #expect(CollisionFixtures.close(wr.separation,w.separation))
        #expect(try CollisionFixtures.vectorClose(wr.pointA,transform.transforming(point:w.pointA)))
        #expect(try CollisionFixtures.vectorClose(wr.pointB,transform.transforming(point:w.pointB)))
        #expect(try CollisionFixtures.vectorClose(wr.normal,transform.transforming(direction:w.normal)))
        let coincident = try queries.witness(first:a,second:CollisionFixtures.moved(b,.zero),policy:policy,work:&work)
        #expect(coincident.degeneracy == .coincidentSphereCenters)
        #expect(coincident.normal == .unitX)
        #expect(CollisionFixtures.close(coincident.separation,-1.8))
        #expect(coincident.originalBalanceResidual <= policy.lengthTolerance)
    }

    @Test func sphereBoxInteriorCornerAndTieAreGeometricallyConsistent() throws {
        let queries: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        var work = try CollisionFixtures.work()
        let policy = try CollisionFixtures.policy()
        let cube = try CollisionFixtures.proxy("box",shape:.box(halfExtents:Vector3(1,1,1)))
        let sphere = try CollisionFixtures.proxy("sphere",shape:.sphere(radius:0.25))
        let inside = try queries.witness(first:sphere,second:cube,policy:policy,work:&work)
        #expect(CollisionFixtures.close(inside.separation,-1.25))
        #expect(try inside.normal == Vector3(-1,0,0))
        #expect(inside.featureB == .boxFace(axis:0,positive:true))
        #expect(inside.degeneracy == .interiorFaceTie)
        #expect(try CollisionFixtures.vectorClose(inside.pointB,Vector3(1,0,0)))
        let corner = try queries.witness(first:CollisionFixtures.moved(sphere,Vector3(2,2,0)),second:cube,policy:policy,work:&work)
        #expect(CollisionFixtures.close(corner.separation,2.0.squareRoot()-0.25))
        #expect(corner.featureB == .boxBoundary(axisMask:3,positiveMask:3))
        #expect(CollisionFixtures.close(try corner.normal.dot(corner.pointB.subtracting(corner.pointA)),corner.separation))
        let reversed = try queries.witness(first:cube,second:CollisionFixtures.moved(sphere,Vector3(2,2,0)),policy:policy,work:&work)
        #expect(CollisionFixtures.close(reversed.separation,corner.separation))
        #expect(try CollisionFixtures.vectorClose(reversed.normal,corner.normal.scaled(by:-1)))
        #expect(reversed.pointA == corner.pointB && reversed.pointB == corner.pointA)
        let rotation = try UnitQuaternion(axis:.unitZ,angle:0.7)
        let rotated = cube.moved(to:RigidTransform(rotation:rotation,translation:try Vector3(2,3,-1)))
        let center = try rotated.pose.transforming(point:Vector3(2,0,0))
        let transformed = try queries.witness(first:CollisionFixtures.moved(sphere,center),second:rotated,policy:policy,work:&work)
        #expect(CollisionFixtures.close(transformed.separation,0.75))
        let tangentEdge = try queries.point(proxy:cube,query:Vector3(2,1,0),policy:policy,work:&work)
        #expect(tangentEdge.feature == .boxBoundary(axisMask:3,positiveMask:3))
        #expect(try tangentEdge.boundaryPoint == Vector3(1,1,0))
        let edgeWorld = try rotated.pose.transforming(point:Vector3(2,1,0))
        let edgePair = try queries.witness(first:CollisionFixtures.moved(sphere,edgeWorld),second:rotated,policy:policy,work:&work)
        #expect(edgePair.featureB == .boxBoundary(axisMask:3,positiveMask:3))
        #expect(CollisionFixtures.close(edgePair.separation,0.75))
    }

    @Test func boxPlaneSupportAndBoundsMatchAllVertices() throws {
        let queries: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        var work = try CollisionFixtures.work()
        let half = try Vector3(1,2,0.5)
        let rotation = try UnitQuaternion(axis:Vector3(1,2,1),angle:0.8)
        let box = try CollisionFixtures.proxy("box",shape:.box(halfExtents:half),position:Vector3(2,-3,1),rotation:rotation)
        let direction = try Vector3(0.4,-0.7,0.3)
        let support = try queries.support(proxy:box,direction:direction,work:&work)
        let bounds = try queries.bounds(proxy:box,work:&work)
        guard case .finite(let lower,let upper) = bounds else { Issue.record("Finite box must have finite bounds"); return }
        for sx in [-1.0,1] { for sy in [-1.0,1] { for sz in [-1.0,1] {
            let vertex = try box.pose.transforming(point:Vector3(sx*half.x,sy*half.y,sz*half.z))
            #expect(try vertex.dot(direction) <= support.point.dot(direction)+1e-10)
            #expect(vertex.x >= lower.x && vertex.x <= upper.x && vertex.y >= lower.y && vertex.y <= upper.y && vertex.z >= lower.z && vertex.z <= upper.z)
        } } }
        let plane = try CollisionFixtures.proxy("plane",shape:.halfSpace)
        let flat = try CollisionFixtures.proxy("flat",shape:.box(halfExtents:Vector3(1,1,1)),position:Vector3(0,0,0.5))
        let w = try queries.witness(first:flat,second:plane,policy:CollisionFixtures.policy(),work:&work)
        #expect(CollisionFixtures.close(w.separation,-0.5))
        #expect(w.featureA == .boxVertex(positiveMask:3))
        #expect(try w.normal == Vector3(0,0,-1))
        #expect(throws:CollisionError.unsupportedPair) { try queries.witness(first:flat,second:box,policy:CollisionFixtures.policy(),work:&work) }
        #expect(throws:CollisionError.unsupportedQuery) { try queries.support(proxy:plane,direction:.unitZ,work:&work) }
    }

    @Test func pointAndRayInsideGrazingParallelAndApproximation() throws {
        let queries: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        var work = try CollisionFixtures.work()
        let policy = try CollisionFixtures.policy()
        let sphere = try CollisionFixtures.proxy("sphere",shape:.sphere(radius:1))
        let box = try CollisionFixtures.proxy("box",shape:.box(halfExtents:Vector3(1,2,3)))
        let plane = try CollisionFixtures.proxy("plane",shape:.halfSpace)
        let inner = try queries.point(proxy:box,query:.zero,policy:policy,work:&work)
        #expect(inner.signedDistance == -1 && inner.boundaryPoint == .unitX)
        let sphereInside = try queries.ray(proxy:sphere,ray:CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10),policy:policy,work:&work)
        #expect(sphereInside?.distance == 1)
        let boxInside = try queries.ray(proxy:box,ray:CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10),policy:policy,work:&work)
        #expect(boxInside?.distance == 1)
        let grazing = try queries.ray(proxy:sphere,ray:CollisionRay(origin:Vector3(-3,1,0),direction:.unitX,maximumDistance:10),policy:policy,work:&work)
        #expect(grazing?.distance == 3)
        #expect(grazing?.outwardNormal == .unitY)
        let planeInside = try queries.ray(proxy:plane,ray:CollisionRay(origin:Vector3(0,0,-1),direction:.unitZ,maximumDistance:10),policy:policy,work:&work)
        #expect(planeInside?.distance == 1)
        let parallel = try queries.ray(proxy:box,ray:CollisionRay(origin:Vector3(2,0,0),direction:.unitZ,maximumDistance:10),policy:policy,work:&work)
        #expect(parallel == nil)
        #expect(throws:CollisionError.invalidRay) { try CollisionRay(origin:.zero,direction:.zero,maximumDistance:1) }
        let inflatedBox = try CollisionFixtures.proxy("inflated",shape:.box(halfExtents:Vector3(1,1,1)),margin:0.1)
        #expect(throws:CollisionError.unsupportedQuery) { try queries.point(proxy:inflatedBox,query:.zero,policy:policy,work:&work) }
        let source = try CollisionFixtures.proxy("source",shape:.sphere(radius:1),position:Vector3(3,0,0))
        let coarse = try CollisionFixtures.proxy("coarse",shape:.sphere(radius:0.9),quality:.approximation(maximumDeviationMeters:0.1),displayKey:"LOD1")
        let fine = try CollisionFixtures.proxy("fine",shape:.sphere(radius:0.99),quality:.approximation(maximumDeviationMeters:0.01))
        let a = try queries.witness(first:coarse,second:source,policy:policy,work:&work)
        let b = try queries.witness(first:fine,second:source,policy:policy,work:&work)
        #expect(CollisionFixtures.close(a.separation,1.1) && CollisionFixtures.close(b.separation,1.01))
        #expect(abs(a.separation-1) <= a.approximationError+1e-10)
        #expect(abs(b.separation-1) <= b.approximationError+1e-10)
        let changedDisplay = try CollisionFixtures.proxy("coarse",shape:.sphere(radius:0.9),quality:.approximation(maximumDeviationMeters:0.1),displayKey:"LOD100")
        let unchanged = try queries.witness(first:changedDisplay,second:source,policy:policy,work:&work)
        #expect(unchanged.separation == a.separation && unchanged.pointA == a.pointA)
        #expect(throws:CollisionError.approximationExceeded(value:0.1,maximum:0.01)) {
            try queries.witness(first:coarse,second:source,policy:CollisionFixtures.policy(maximumError:0.01),work:&work)
        }
    }

    @Test func invalidShapeFrameRepresentationAndArithmeticAreExplicit() throws {
        #expect(throws:CollisionError.invalidShape) { try CollisionFixtures.proxy("bad",shape:.sphere(radius:0)) }
        #expect(throws:CollisionError.invalidShape) { try CollisionFixtures.proxy("bad",shape:.box(halfExtents:Vector3(1,0,1))) }
        let queries: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        var work = try CollisionFixtures.work()
        let a = try CollisionFixtures.proxy("a",shape:.sphere(radius:1))
        let b = try CollisionFixtures.proxy("b",shape:.sphere(radius:1),frameRevision:2)
        #expect(throws:CollisionError.frameMismatch) { try queries.witness(first:a,second:b,policy:CollisionFixtures.policy(),work:&work) }
        let huge = try CollisionFixtures.proxy("huge",shape:.sphere(radius:Double.greatestFiniteMagnitude),position:Vector3(.greatestFiniteMagnitude,0,0))
        #expect(throws:CollisionError.self) { try queries.bounds(proxy:huge,work:&work) }
        var limited = try CollisionFixtures.work(operations:0)
        #expect(throws:CollisionError.resourceLimit(resource:.operations,limit:0)) { try queries.point(proxy:a,query:.zero,policy:CollisionFixtures.policy(),work:&limited) }
    }
}
