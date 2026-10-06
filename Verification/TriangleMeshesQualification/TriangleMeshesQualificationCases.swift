import SwiftMechanics

public enum TriangleMeshesQualificationCases {
    private typealias F = TriangleMeshesQualificationFixture
    private static func check(_ condition: Bool, _ reason: String) throws {
        guard condition else { throw TriangleMeshesQualificationError.assertion(reason) }
    }
    private static func near(_ value: Double, _ expected: Double, _ reason: String) throws {
        try check(value.isFinite && abs(value - expected) <= 1e-8, reason)
    }
    private static func vector(_ value: Vector3, _ x: Double, _ y: Double, _ z: Double, _ reason: String) throws {
        try near(value.x, x, reason + ".x"); try near(value.y, y, reason + ".y"); try near(value.z, z, reason + ".z")
    }
    private static func refused(_ expected: TriangleMeshError, _ operation: () throws -> Void) throws {
        do { try operation() } catch let error as TriangleMeshError {
            try check(error == expected, "typed original triangle cause: \(error)"); return
        }
        throw TriangleMeshesQualificationError.assertion("unexpected triangle success")
    }
    private static func ledger(_ work: CollisionWork, operations: Int, storage: Int, iterations: Int = 0) throws {
        try check(work.operations == operations && work.peakScalarStorage == storage && work.iterations == iterations,
                  "exact consumed operation / storage / iteration ledger")
    }
    private static func pointBalance(_ value: TriangleMeshPoint, query: Vector3) throws {
        let offset = try query.subtracting(value.boundaryPoint)
        let balance = try offset.subtracting(value.normal.scaled(by: value.distance)).magnitude()
        try near(balance, 0, "original query-boundary normal-distance balance")
        try near(value.originalBalanceResidual, 0, "original point residual")
        try near(value.normal.magnitude(), 1, "original unit normal")
        try near(value.barycentricWeights.x + value.barycentricWeights.y + value.barycentricWeights.z, 1, "original barycentric sum")
    }
    private static func hit(_ value: TriangleMeshRayHit?) throws -> TriangleMeshRayHit {
        guard let value else { throw TriangleMeshesQualificationError.assertion("missing original ray hit") }; return value
    }
    private static func toi(_ value: TriangleMeshSphereTOI?) throws -> TriangleMeshSphereTOI {
        guard let value else { throw TriangleMeshesQualificationError.assertion("missing original sphere impact") }; return value
    }

    public static func manufacturedPointFeatures() throws {
        let mesh = try F.triangle(); var work = try F.work()
        let queries = try [F.vector(0.5, 0.5, 3), F.vector(1, -1, 2), F.vector(-1, -1, 2)]
        let points = try queries.map { try F.service().point(mesh: mesh, query: $0, policy: F.policy(), work: &work) }
        try vector(points[0].boundaryPoint, 0.5, 0.5, 0, "literal face point")
        try vector(points[0].barycentricWeights, 0.5, 0.25, 0.25, "literal face weights")
        try near(points[0].distance, 3, "literal face distance"); try check(points[0].feature == .face(id: 41), "original face ID")
        try vector(points[1].boundaryPoint, 1, 0, 0, "literal edge point")
        try vector(points[1].barycentricWeights, 0.5, 0.5, 0, "literal edge weights")
        try near(points[1].distance, 5.0.squareRoot(), "literal edge distance")
        try check(points[1].feature == .edge(firstVertex: 0, secondVertex: 1), "original edge indices")
        try vector(points[2].boundaryPoint, 0, 0, 0, "literal vertex point")
        try vector(points[2].barycentricWeights, 1, 0, 0, "literal vertex weights")
        try near(points[2].distance, 6.0.squareRoot(), "literal vertex distance")
        try check(points[2].feature == .vertex(index: 0), "original vertex index")
        for i in queries.indices {
            try pointBalance(points[i], query: queries[i])
            try check(points[i].geometry == mesh.geometry && points[i].pose == mesh.pose && points[i].faceID == 41,
                      "original mesh identity/source/face lifetime")
        }
        let boundary = try F.service().point(mesh: mesh, query: F.vector(0.5, 0.5), policy: F.policy(), work: &work)
        try check(boundary.usesFaceNormalAtBoundary && boundary.distance == 0, "exact unsigned boundary convention")
        try vector(boundary.normal, 0, 0, 1, "original face orientation")
        let below = try F.service().point(mesh: mesh, query: F.vector(0.5, 0.5, -3), policy: F.policy(), work: &work)
        try near(below.distance, 3, "unsigned negative plane side"); try vector(below.normal, 0, 0, -1, "toward query unsigned normal")
        let moved = mesh.moved(to: try F.pose(10, -2, 1, rotation: UnitQuaternion(axis: .unitY, angle: .pi / 2)))
        let worldQuery = try F.vector(13, -1.5, 0.5)
        let world = try F.service().point(mesh: moved, query: worldQuery, policy: F.policy(), work: &work)
        try vector(world.boundaryPoint, 10, -1.5, 0.5, "independent transformed face point")
        try vector(world.normal, 1, 0, 0, "independent transformed normal")
        try vector(world.barycentricWeights, 0.5, 0.25, 0.25, "transform preserves original barycentrics")
        try near(world.distance, 3, "rigid transformed original distance"); try pointBalance(world, query: worldQuery)
    }

    public static func originalHierarchyRayAndBounds() throws {
        var work = try F.work()
        let originalVertices = try [F.vector(0), F.vector(2), F.vector(0, 2), F.vector(10), F.vector(12), F.vector(10, 2)]
        let originalFaces = [F.face(90), F.face(10, 3, 4, 5)]
        let separated = try F.mesh(vertices: originalVertices, faces: originalFaces, work: &work)
        let strict = try F.service().point(mesh: separated, query: F.vector(5, 0.5, 2), policy: F.policy(), work: &work)
        // Exhaustive literal vertex distances are sqrt13.25 and sqrt29.25; smaller face ID cannot override geometry.
        try near(strict.distance, 13.25.squareRoot(), "independent full-face minimum")
        try vector(strict.boundaryPoint, 2, 0, 0, "independent nearer original vertex")
        try check(strict.faceID == 90 && strict.feature == .vertex(index: 1), "strict minimum preserves source feature")
        let tie = try F.service().point(mesh: separated, query: F.vector(6, 0, 1), policy: F.policy(), work: &work)
        try near(tie.distance, 17.0.squareRoot(), "independent equidistant patches")
        try check(tie.faceID == 10 && tie.feature == .vertex(index: 3) && tie.numericalTieCount == 2, "hierarchy deterministic original face tie")
        let reversed = try F.mesh(vertices: originalVertices, faces: Array(originalFaces.reversed()), work: &work)
        let again = try F.service().point(mesh: reversed, query: F.vector(6, 0, 1), policy: F.policy(), work: &work)
        try check(again.faceID == tie.faceID && again.feature == tie.feature, "face inventory permutation preserves tie")
        let square = try F.square()
        let seam = try F.service().point(mesh: square, query: F.vector(1, 1, 2), policy: F.policy(), work: &work)
        try check(seam.faceID == 10 && seam.feature == .edge(firstVertex: 0, secondVertex: 2) && seam.numericalTieCount == 2,
                  "original seam identity and evaluated tie count")
        let down = try F.vector(0, 0, -1)
        let seamRay = try hit(F.service().ray(mesh: square, ray: F.ray(1, 1, 3, direction: down), policy: F.policy(), work: &work))
        try near(seamRay.distance, 3, "original seam ray distance")
        try check(seamRay.faceID == 10 && seamRay.numericalTieCount == 2 && seamRay.feature == .edge(firstVertex: 0, secondVertex: 2),
                  "nearest ray original face tie")
        try vector(seamRay.barycentricWeights, 0.5, 0.5, 0, "literal seam ray weights")
        let layeredVertices = try F.vertices() + F.vertices(height: 1)
        for faces in [[F.face(90), F.face(10, 3, 4, 5)], [F.face(10, 3, 4, 5), F.face(90)]] {
            let layered = try F.mesh(vertices: layeredVertices, faces: faces, work: &work)
            let value = try hit(F.service().ray(mesh: layered, ray: F.ray(direction: down), policy: F.policy(), work: &work))
            try near(value.distance, 2, "nearest layered ray")
            try vector(value.point, 0.5, 0.5, 1, "literal first original surface")
            try check(value.faceID == 10 && value.feature == .face(id: 10) && value.geometry == layered.geometry,
                      "nearest hit source is original, independent of inventory order")
            try near(value.originalResidual, 0, "ray original reconstruction")
            try check(F.service().ray(mesh: layered, ray: F.ray(5, 5, 3, direction: down), policy: F.policy(), work: &work) == nil,
                      "all original faces reject geometric ray miss")
        }
        let triangle = try F.triangle()
        try check(F.service().ray(mesh: triangle, ray: F.ray(3, 3, 0, direction: .unitX), policy: F.policy(), work: &work) == nil,
                  "original coplanar interval proves miss")
        let placed = square.moved(to: try F.pose(10, -2, 1, rotation: UnitQuaternion(axis: .unitZ, angle: .pi / 2)))
        let bounds = try F.service().bounds(mesh: placed, work: &work)
        guard case .finite(let lower, let upper) = bounds else { throw TriangleMeshesQualificationError.assertion("mesh bounds not finite") }
        try vector(lower, 8, -2, 1, "literal rotated lower bounds")
        try vector(upper, 10, 0, 1, "literal rotated upper bounds")
        for expected in try [F.vector(10, -2, 1), F.vector(10, 0, 1), F.vector(8, 0, 1), F.vector(8, -2, 1)] {
            try check(lower.x <= expected.x && expected.x <= upper.x && lower.y <= expected.y && expected.y <= upper.y
                      && lower.z <= expected.z && expected.z <= upper.z, "conservative bounds contain original transformed vertex")
        }
    }

    public static func selectedSignedTetrahedron() throws {
        let mesh = try F.tetrahedron(); var work = try F.work()
        let insideQuery = try F.vector(0.25, 0.25, 0.25)
        let inside = try F.service().point(mesh: mesh, query: insideQuery, policy: F.policy(), work: &work)
        try near(inside.distance, -0.25, "certified tetrahedron signed inside")
        try vector(inside.boundaryPoint, 0.25, 0.25, 0, "literal inside nearest bottom face")
        try vector(inside.normal, 0, 0, -1, "inside outward normal")
        try vector(inside.barycentricWeights, 0.75, 0.125, 0.125, "literal signed barycentrics")
        try check(inside.faceID == 10 && inside.numericalTieCount == 3, "three original interior faces tie")
        try pointBalance(inside, query: insideQuery)
        let outsideQuery = try F.vector(3)
        let outside = try F.service().point(mesh: mesh, query: outsideQuery, policy: F.policy(), work: &work)
        try near(outside.distance, 1, "certified tetrahedron signed outside")
        try vector(outside.boundaryPoint, 2, 0, 0, "literal tetrahedron outside vertex")
        try check(outside.feature == .vertex(index: 1) && outside.faceID == 10, "outside source feature tie")
        try pointBalance(outside, query: outsideQuery)
        let boundary = try F.service().point(mesh: mesh, query: F.vector(0.5, 0.5), policy: F.policy(), work: &work)
        try check(boundary.distance == 0 && boundary.usesFaceNormalAtBoundary, "exact signed boundary convention")
        try vector(boundary.normal, 0, 0, -1, "original signed boundary orientation")
        try refused(.uncertifiedSolid) {
            _ = try F.service().point(mesh: mesh, query: F.vector(0.25, 0.25, 1e-12), policy: F.policy(), work: &work)
        }
        try refused(.uncertifiedSolid) {
            _ = try F.mesh(vertices: F.vertices(), faces: [F.face()], distancePolicy: .certifiedTetrahedralSolid, work: &work)
        }
        let inward = mesh.geometry.faces.map { F.face($0.id, $0.a, $0.c, $0.b) }
        try refused(.uncertifiedSolid) {
            _ = try F.mesh(vertices: mesh.geometry.vertices, faces: inward, distancePolicy: .certifiedTetrahedralSolid, work: &work)
        }
    }

    public static func refitOriginalSnapshotLifetime() throws {
        var work = try F.work(); var callerVertices = try F.vertices()
        let original = try F.mesh(vertices: callerVertices, faces: [F.face()], work: &work)
        let oldPoint = try F.service().point(mesh: original, query: F.vector(0.5, 0.5, 3), policy: F.policy(), work: &work)
        callerVertices[0] = try F.vector(99, 99, 99)
        try check(original.geometry.vertices == F.vertices(), "caller mutation cannot change retained original vertices")
        let revisedVertices = try F.vertices(height: 1), revisedRepresentation = try F.representation(revision: 8, deviation: 0.02)
        var refitWork = try F.work()
        let updated = try original.refitted(vertices: revisedVertices, representation: revisedRepresentation,
            expectedSourceRevision: 8, geometryRevision: 12, work: &refitWork)
        try ledger(refitWork, operations: 1_496, storage: 1_200)
        let newPoint = try F.service().point(mesh: updated, query: F.vector(0.5, 0.5, 3), policy: F.policy(), work: &work)
        try near(newPoint.distance, 2, "refitted original plane distance")
        try vector(newPoint.boundaryPoint, 0.5, 0.5, 1, "refitted original plane point")
        try check(updated.geometry.faces == original.geometry.faces && newPoint.faceID == oldPoint.faceID,
                  "refit preserves original connectivity and stable face ID")
        try check(updated.geometry.vertices == revisedVertices && updated.geometry.representation == revisedRepresentation
                  && updated.geometry.geometryRevision == 12 && updated.geometry.frameRevision == 9, "new source snapshot authority")
        try check(oldPoint.geometry == original.geometry && original.geometry.vertices == F.vertices()
                  && oldPoint.geometry.representation.provenance.revision == 7, "old output retains original source lifetime")
        try near(oldPoint.distance, 3, "old retained result unchanged")
        let oldAgain = try F.service().point(mesh: original, query: F.vector(0.5, 0.5, 3), policy: F.policy(), work: &work)
        try near(oldAgain.distance, 3, "original mesh still usable after refit")
        var published = updated
        try refused(.degenerateTriangle(faceID: 41)) {
            published = try original.refitted(vertices: [F.vector(0), F.vector(1), F.vector(2)],
                representation: revisedRepresentation, expectedSourceRevision: 8, geometryRevision: 12, work: &work)
        }
        try check(published.geometry == updated.geometry, "failed refit does not publish partial source")
        for change in [try F.representation(revision: 7), try F.representation(revision: 8, source: "otherSource")] {
            try refused(.collision(.staleGeometry)) {
                _ = try original.refitted(vertices: revisedVertices, representation: change,
                    expectedSourceRevision: change.provenance.revision, geometryRevision: 12, work: &work)
            }
        }
        try refused(.collision(.staleGeometry)) {
            _ = try original.refitted(vertices: revisedVertices, representation: revisedRepresentation,
                expectedSourceRevision: 8, geometryRevision: 11, work: &work)
        }
        let bounds = try F.service().bounds(mesh: updated, work: &work)
        guard case .finite(let lower, let upper) = bounds else { throw TriangleMeshesQualificationError.assertion("refit bounds missing") }
        try check(lower.z <= 1 && upper.z >= 1 && lower.z > 0.9 && upper.z < 1.1, "refit recomputes original leaf bounds")
    }

    private static func bracket(_ value: TriangleMeshSphereTOI, expectedTime: Double, maximumWidth: Double,
                                expectedFeature: TriangleMeshFeature) throws {
        try check(!value.initialOverlap && value.lowerTime <= expectedTime && expectedTime <= value.upperTime,
                  "independent original impact lies in returned bracket")
        try check(value.lowerSeparation > 0 && value.upperContact.separation <= 0
                  && value.upperTime - value.lowerTime <= maximumWidth, "original positive/nonpositive bounded bracket")
        try check(value.upperContact.meshPoint.feature == expectedFeature, "original sphere impact feature")
        try near(value.upperContact.originalBalanceResidual, 0, "original sphere-to-mesh residual")
        let offset = try value.upperContact.meshPoint.boundaryPoint.subtracting(value.upperContact.spherePoint)
        try near(offset.subtracting(value.upperContact.normalFromSphereToMesh.scaled(by: value.upperContact.separation)).magnitude(),
                 0, "original sphere contact balance")
    }

    public static func originalSphereAdvanceAndMiss() throws {
        let mesh = try F.triangle(deviation: 0.03); let sweep = try F.staticSweep(mesh)
        let sphere = try F.sphereSweep(radius: 0.25, margin: 0.25, deviation: 0.02)
        var work = try F.work()
        let face = try toi(F.service().timeOfImpact(sphere: sphere, mesh: sweep, durationSeconds: 10,
            maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &work))
        try bracket(face, expectedTime: 6.25, maximumWidth: 0.01, expectedFeature: .face(id: 41))
        try near(face.lowerTime, 6.243896484375, "literal binary lower face bracket")
        try near(face.upperTime, 6.25, "literal upper face impact")
        try vector(face.upperContact.meshPoint.boundaryPoint, 0.5, 0.5, 0, "literal face contact")
        try vector(face.upperContact.spherePoint, 0.5, 0.5, 0, "original effective-radius sphere surface")
        try near(face.upperContact.approximationError, 0.05, "original sphere and mesh quality sum")
        try check(face.upperContact.sphereGeometry == sphere.start.geometry && face.upperContact.meshPoint.geometry == mesh.geometry,
                  "original CCD source identities")
        try ledger(work, operations: 21_408, storage: 1_200, iterations: 10)
        try check(face.iterations == 10, "actual bracket refinement count")
        let edgeSphere = try F.sphereSweep(x: 1, y: -0.75, endZ: -3, radius: 1.25)
        let edge = try toi(F.service().timeOfImpact(sphere: edgeSphere, mesh: sweep, durationSeconds: 6,
            maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &work))
        try bracket(edge, expectedTime: 2, maximumWidth: 0.01, expectedFeature: .edge(firstVertex: 0, secondVertex: 1))
        try vector(edge.upperContact.meshPoint.boundaryPoint, 1, 0, 0, "literal original edge impact")
        let vertexSphere = try F.sphereSweep(x: -0.5, y: -1, endZ: -3, radius: 1.5)
        let vertex = try toi(F.service().timeOfImpact(sphere: vertexSphere, mesh: sweep, durationSeconds: 6,
            maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &work))
        try bracket(vertex, expectedTime: 2, maximumWidth: 0.01, expectedFeature: .vertex(index: 0))
        try vector(vertex.upperContact.meshPoint.boundaryPoint, 0, 0, 0, "literal original vertex impact")
        let fast = try F.sphereSweep(startZ: 1_000, endZ: -1_000)
        let rapid = try toi(F.service().timeOfImpact(sphere: fast, mesh: sweep, durationSeconds: 1,
            maximumTimeWidthSeconds: 0.001, policy: F.policy(), work: &work))
        try bracket(rapid, expectedTime: 0.49975, maximumWidth: 0.001, expectedFeature: .face(id: 41))
        let stationary = try F.sphereSweep(startZ: 3, endZ: 3)
        let movingMesh = try TriangleMeshSweep(start: mesh, end: mesh.moved(to: F.pose(0, 0, 4)))
        let relative = try toi(F.service().timeOfImpact(sphere: stationary, mesh: movingMesh, durationSeconds: 10,
            maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &work))
        try bracket(relative, expectedTime: 6.25, maximumWidth: 0.01, expectedFeature: .face(id: 41))
        try vector(relative.upperContact.meshPoint.boundaryPoint, 0.5, 0.5, 2.5, "actual translating mesh surface")
        let overlapping = try F.sphereSweep(startZ: 0.25, endZ: 3)
        let initial = try toi(F.service().timeOfImpact(sphere: overlapping, mesh: sweep, durationSeconds: 10,
            maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &work))
        try check(initial.initialOverlap && initial.lowerTime == 0 && initial.upperTime == 0 && initial.iterations == 0,
                  "actual original initial overlap")
        try near(initial.upperContact.separation, -0.25, "literal initial penetration")
        var missWork = try F.work()
        let miss = try F.service().timeOfImpact(sphere: F.sphereSweep(x: 5, y: 5, endZ: -3), mesh: sweep,
            durationSeconds: 6, maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &missWork)
        try check(miss == nil, "moving sphere all original features certify miss")
        try ledger(missWork, operations: 9_352, storage: 1_200)
    }

    public static func exactWorkAndCapacity() throws {
        var admission = try F.work(operations: 1_624, storage: 1_200, records: 19)
        let mesh = try F.mesh(vertices: F.vertices(), faces: [F.face()], work: &admission)
        try ledger(admission, operations: 1_624, storage: 1_200)
        var point = try F.work(operations: 1_096, storage: 1_200, records: 19)
        _ = try F.service().point(mesh: mesh, query: F.vector(0.5, 0.5, 3), policy: F.policy(), work: &point)
        try ledger(point, operations: 1_096, storage: 1_200)
        let down = try F.vector(0, 0, -1)
        var ray = try F.work(operations: 2_120, storage: 1_200, records: 19)
        _ = try hit(F.service().ray(mesh: mesh, ray: F.ray(direction: down), policy: F.policy(), work: &ray))
        try ledger(ray, operations: 2_120, storage: 1_200)
        var miss = try F.work(operations: 2_112, storage: 1_200, records: 19)
        try check(F.service().ray(mesh: mesh, ray: F.ray(5, 5, 3, direction: down), policy: F.policy(), work: &miss) == nil,
                  "literal miss with exact consumed work")
        try ledger(miss, operations: 2_112, storage: 1_200)
        var bounds = try F.work(operations: 2_048, storage: 1_200, records: 19)
        _ = try F.service().bounds(mesh: mesh, work: &bounds); try ledger(bounds, operations: 2_048, storage: 1_200)
        var shortAdmission = try F.work(operations: 1_623)
        try refused(.collision(.resourceLimit(resource: .operations, limit: 1_623))) {
            _ = try F.mesh(vertices: F.vertices(), faces: [F.face()], work: &shortAdmission)
        }
        try ledger(shortAdmission, operations: 1_496, storage: 1_200)
        var shortPoint = try F.work(operations: 1_095)
        try refused(.collision(.resourceLimit(resource: .operations, limit: 1_095))) {
            _ = try F.service().point(mesh: mesh, query: F.vector(0.5, 0.5, 3), policy: F.policy(), work: &shortPoint)
        }
        try ledger(shortPoint, operations: 1_088, storage: 1_200)
        var shortRay = try F.work(operations: 2_119)
        try refused(.collision(.resourceLimit(resource: .operations, limit: 2_119))) {
            _ = try F.service().ray(mesh: mesh, ray: F.ray(direction: down), policy: F.policy(), work: &shortRay)
        }
        try ledger(shortRay, operations: 2_112, storage: 1_200)
        var shortStorage = try F.work(storage: 1_199)
        try refused(.collision(.resourceLimit(resource: .scalarStorage, limit: 1_199))) {
            _ = try F.service().point(mesh: mesh, query: F.vector(0), policy: F.policy(), work: &shortStorage)
        }
        try ledger(shortStorage, operations: 64, storage: 0)
        var shortRecords = try F.work(records: 18)
        try refused(.collision(.resourceLimit(resource: .records, limit: 18))) {
            _ = try F.service().point(mesh: mesh, query: F.vector(0), policy: F.policy(), work: &shortRecords)
        }
        try ledger(shortRecords, operations: 64, storage: 1_200)
        var shortRefit = try F.work(operations: 1_495); var published = mesh
        try refused(.collision(.resourceLimit(resource: .operations, limit: 1_495))) {
            published = try mesh.refitted(vertices: F.vertices(height: 1), representation: F.representation(revision: 8),
                expectedSourceRevision: 8, geometryRevision: 12, work: &shortRefit)
        }
        try check(published.geometry == mesh.geometry, "refit resource failure keeps original publication")
        try ledger(shortRefit, operations: 1_368, storage: 1_200)
        var noIterations = try F.work(iterations: 0)
        try refused(.nonConvergence(iterations: 0)) {
            _ = try F.service().timeOfImpact(sphere: F.sphereSweep(), mesh: F.staticSweep(mesh), durationSeconds: 10,
                maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &noIterations)
        }
        try ledger(noIterations, operations: 10_448, storage: 1_200)
        var zero = try F.work(operations: 0)
        try refused(.collision(.resourceLimit(resource: .operations, limit: 0))) {
            _ = try F.service().bounds(mesh: mesh, work: &zero)
        }
        try ledger(zero, operations: 0, storage: 0)
    }

    public static func explicitGeometricAndAdmissionRefusals() throws {
        var work = try F.work(); let mesh = try F.triangle()
        try refused(.degenerateTriangle(faceID: 41)) {
            _ = try F.mesh(vertices: [F.vector(0), F.vector(1), F.vector(2)], faces: [F.face()], work: &work)
        }
        try refused(.invalidMesh) { _ = try F.mesh(vertices: F.vertices(), faces: [F.face(), F.face()], work: &work) }
        try refused(.invalidMesh) { _ = try F.mesh(vertices: F.vertices(), faces: [F.face(41, 0, 0, 2)], work: &work) }
        try refused(.invalidMesh) { _ = try F.mesh(vertices: F.vertices() + [F.vector(9, 9, 9)], faces: [F.face()], work: &work) }
        try refused(.nonmanifoldMesh) {
            _ = try F.mesh(vertices: [F.vector(0), F.vector(2), F.vector(0, 2), F.vector(-2), F.vector(0, -2)],
                faces: [F.face(1), F.face(2, 0, 3, 4)], work: &work)
        }
        try refused(.nonmanifoldMesh) {
            _ = try F.mesh(vertices: F.vertices(), faces: [F.face(1), F.face(2)], work: &work)
        }
        try refused(.collision(.invalidIdentity)) {
            _ = try F.mesh(vertices: F.vertices(), faces: [F.face()], collider: F.id(.body, "wrongKind"), work: &work)
        }
        try refused(.collision(.staleGeometry)) {
            _ = try F.mesh(vertices: F.vertices(), faces: [F.face()], expectedSourceRevision: 8, work: &work)
        }
        let coarse = try F.triangle(deviation: 0.03)
        try refused(.collision(.approximationExceeded(value: 0.03, maximum: 0.02))) {
            _ = try F.service().point(mesh: coarse, query: F.vector(0.5, 0.5, 3), policy: F.policy(maximumError: 0.02), work: &work)
        }
        try refused(.ambiguousRay(faceID: 41)) {
            _ = try F.service().ray(mesh: mesh, ray: F.ray(0.5, 0.5, 0, direction: .unitX), policy: F.policy(), work: &work)
        }
        try refused(.ambiguousRay(faceID: 41)) {
            _ = try F.service().ray(mesh: mesh, ray: F.ray(2 + 1e-12, 0, 3, direction: F.vector(0, 0, -1)),
                policy: F.policy(), work: &work)
        }
        try refused(.ambiguousSweep) {
            _ = try F.service().timeOfImpact(sphere: F.sphereSweep(x: 1, y: -1, startZ: 1, endZ: -1, radius: 1),
                mesh: F.staticSweep(mesh), durationSeconds: 2, maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &work)
        }
        try refused(.unsupportedSweep) {
            _ = try TriangleMeshSweep(start: mesh, end: mesh.moved(to: F.pose(rotation: UnitQuaternion(axis: .unitZ, angle: .pi / 2))))
        }
        let wrongFrame = try F.sphere(position: F.vector(0.5, 0.5, 3), frame: "other")
        let wrongSweep = try CollisionSweep(start: wrongFrame, end: wrongFrame)
        try refused(.collision(.frameMismatch)) {
            _ = try F.service().timeOfImpact(sphere: wrongSweep, mesh: F.staticSweep(mesh), durationSeconds: 1,
                maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &work)
        }
        let box = try F.sphere(position: F.vector(0.5, 0.5, 3), shape: .box(halfExtents: F.vector(1, 1, 1)))
        try refused(.unsupportedSweep) {
            _ = try F.service().timeOfImpact(sphere: CollisionSweep(start: box, end: box), mesh: F.staticSweep(mesh),
                durationSeconds: 1, maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &work)
        }
        try refused(.collision(.invalidPolicy)) {
            _ = try F.service().timeOfImpact(sphere: F.sphereSweep(), mesh: F.staticSweep(mesh), durationSeconds: 0,
                maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &work)
        }
        try refused(.collision(.arithmeticFailure)) {
            _ = try F.service().bounds(mesh: mesh.moved(to: F.pose(Double.greatestFiniteMagnitude)), work: &work)
        }
    }

    public static func cancelledTask(mesh: TriangleMesh) throws {
        try check(Task.isCancelled, "actual awaited Task is cancelled")
        var work = try F.work()
        try refused(.collision(.cancelled)) {
            _ = try F.service().point(mesh: mesh, query: F.vector(0.5, 0.5, 3), policy: F.policy(), work: &work)
        }
        try refused(.collision(.cancelled)) {
            _ = try F.service().ray(mesh: mesh, ray: F.ray(), policy: F.policy(), work: &work)
        }
        try refused(.collision(.cancelled)) { _ = try F.service().bounds(mesh: mesh, work: &work) }
        try refused(.collision(.cancelled)) {
            _ = try mesh.refitted(vertices: F.vertices(height: 1), representation: F.representation(revision: 8),
                expectedSourceRevision: 8, geometryRevision: 12, work: &work)
        }
        try refused(.collision(.cancelled)) { _ = try F.mesh(vertices: F.vertices(), faces: [F.face()], work: &work) }
        try refused(.collision(.cancelled)) {
            _ = try F.service().timeOfImpact(sphere: F.sphereSweep(), mesh: F.staticSweep(mesh), durationSeconds: 10,
                maximumTimeWidthSeconds: 0.01, policy: F.policy(), work: &work)
        }
        try ledger(work, operations: 0, storage: 0)
    }
}
