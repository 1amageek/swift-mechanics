import SwiftMechanics

public enum ConvexQueriesQualificationFixtures {
    public static func work(operations: Int = 50_000_000, iterations: Int = 200,
                            storage: Int = 200_000, records: Int = 4096) throws -> CollisionWork {
        CollisionWork(budget: try CollisionBudget(scalarStorage: storage, operations: operations,
                                                 iterations: iterations, records: records))
    }

    public static func policy(error: Double = 0.1) throws -> CollisionQueryPolicy {
        try CollisionQueryPolicy(absoluteLengthTolerance: 1e-8, relativeLengthTolerance: 1e-9,
                                 referenceLength: 1, maximumApproximationError: error)
    }

    public static func representation(revision: UInt64 = 1,
                                      quality: RepresentationQuality = .exact) throws -> GeometryRepresentation {
        try GeometryRepresentation(kind: .collisionGeometry, assetKey: "original-convex-proxy",
            provenance: SourceProvenance(source: "convex-original", revision: revision), quality: quality)
    }

    public static func proxy(_ key: String, shape: ConvexShape, position: Vector3 = .zero,
                             rotation: UnitQuaternion = .identity, margin: Double = 0,
                             frame: String = "world", frameRevision: UInt64 = 1,
                             sourceRevision: UInt64 = 1, expectedSource: UInt64 = 1,
                             geometryRevision: UInt64 = 1, quality: RepresentationQuality = .exact,
                             work: inout CollisionWork) throws -> ConvexProxy {
        try ConvexProxy(colliderID: EntityID(kind: .collider, key: key),
            bodyID: EntityID(kind: .body, key: key + "-body"), frameID: EntityID(kind: .frame, key: frame),
            geometryRevision: geometryRevision, frameRevision: frameRevision, shape: shape, margin: margin,
            representations: BodyRepresentations(collisionGeometry: representation(revision: sourceRevision, quality: quality)),
            expectedSourceRevision: expectedSource, resolution: .analytic,
            pose: RigidTransform(rotation: rotation, translation: position), work: &work)
    }

    public static func analytic(_ key: String, shape: CollisionShape, position: Vector3 = .zero,
                                margin: Double = 0) throws -> CollisionProxy {
        try CollisionProxy(colliderID: EntityID(kind: .collider, key: key),
            bodyID: EntityID(kind: .body, key: key + "-body"), frameID: EntityID(kind: .frame, key: "world"),
            geometryRevision: 1, frameRevision: 1, shape: shape, margin: margin,
            representations: BodyRepresentations(collisionGeometry: representation()), expectedSourceRevision: 1,
            resolution: .analytic, pose: RigidTransform(rotation: .identity, translation: position),
            filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: .max, isTrigger: false))
    }

    public static func cube() throws -> [Vector3] {
        try [Vector3(-1,-1,-1), Vector3(1,-1,-1), Vector3(-1,1,-1), Vector3(1,1,-1),
             Vector3(-1,-1,1), Vector3(1,-1,1), Vector3(-1,1,1), Vector3(1,1,1)]
    }

    public static func check(_ value: Bool, _ message: String) throws {
        guard value else { throw ConvexQueriesQualificationError.assertion(message) }
    }

    public static func scalar(_ actual: Double, _ expected: Double, _ message: String) throws {
        try check(actual.isFinite && abs(actual-expected) <= 2.2e-8, message)
    }

    public static func vector(_ actual: Vector3, _ expected: Vector3, _ message: String) throws {
        try scalar(actual.x, expected.x, message + " x")
        try scalar(actual.y, expected.y, message + " y")
        try scalar(actual.z, expected.z, message + " z")
    }

    public static func refuses(_ expected: ConvexCollisionError, _ operation: () throws -> Void) throws {
        do { try operation() }
        catch let error as ConvexCollisionError {
            try check(error == expected, "Wrong convex typed failure"); return
        } catch { throw ConvexQueriesQualificationError.assertion("Unexpected supplier failure") }
        throw ConvexQueriesQualificationError.assertion("Expected convex failure")
    }

    /// Independent scalar extremum of the explicit shape, transformed into the supplied frame.
    public static func supportValue(_ proxy: ConvexProxy, _ direction: Vector3) throws -> Double {
        let d = try proxy.pose.rotation.conjugated().rotating(direction)
        let norm = (d.x*d.x + d.y*d.y + d.z*d.z).squareRoot()
        let radial = (d.x*d.x + d.y*d.y).squareRoot()
        let value: Double
        switch proxy.geometry.shape {
        case .sphere(let radius): value = radius*norm
        case .box(let half): value = half.x*abs(d.x) + half.y*abs(d.y) + half.z*abs(d.z)
        case .capsule(let radius, let half): value = radius*norm + half*abs(d.z)
        case .cylinder(let radius, let half): value = radius*radial + half*abs(d.z)
        case .cone(let radius, let half): value = max(half*d.z, radius*radial-half*d.z)
        case .hull(let vertices):
            var maximum = -Double.infinity
            for v in vertices { maximum = max(maximum, v.x*d.x+v.y*d.y+v.z*d.z) }
            value = maximum
        }
        let t = proxy.pose.translation
        return value + t.x*direction.x+t.y*direction.y+t.z*direction.z + proxy.geometry.margin*norm
    }

    public static func certificate(_ witness: ConvexCollisionWitness, first: ConvexProxy,
                                   second: ConvexProxy, expected: Double) throws {
        try scalar(witness.separation, expected, "Independent signed separation")
        try check(witness.pair.first == first.geometry && witness.pair.second == second.geometry,
                  "Original geometry identity retained")
        try check(witness.poseA == first.pose && witness.poseB == second.pose, "Original poses retained")
        try check(!witness.supports.isEmpty && witness.supports.count <= 4, "Owned simplex cardinality")
        var sum = 0.0, pa = Vector3.zero, pb = Vector3.zero
        for weighted in witness.supports {
            try check(weighted.weight.isFinite && weighted.weight >= 0, "Nonnegative finite original weight")
            sum += weighted.weight
            pa = try pa.adding(weighted.first.point.scaled(by: weighted.weight))
            pb = try pb.adding(weighted.second.point.scaled(by: weighted.weight))
            try scalar(weighted.first.point.dot(weighted.first.direction),
                       supportValue(first, weighted.first.direction), "First original support extremum")
            try scalar(weighted.second.point.dot(weighted.second.direction),
                       supportValue(second, weighted.second.direction), "Second original support extremum")
            try scalar(weighted.first.direction.magnitude(), 1, "First normalized direction")
            try scalar(weighted.second.direction.magnitude(), 1, "Second normalized direction")
            for (proxy, support) in [(first, weighted.first), (second, weighted.second)] {
                if case .hull(let vertices) = proxy.geometry.shape {
                    guard case .hullVertex(let index) = support.feature else {
                        throw ConvexQueriesQualificationError.assertion("Original hull feature missing")
                    }
                    try check(vertices.indices.contains(index), "Original hull index")
                    let original = try proxy.pose.transforming(point: vertices[index])
                        .adding(support.direction.scaled(by: proxy.geometry.margin))
                    try vector(support.point, original, "Original hull vertex support")
                }
            }
        }
        try scalar(sum, 1, "Barycentric unity")
        try vector(pa, witness.pointA, "First original reconstruction")
        try vector(pb, witness.pointB, "Second original reconstruction")
        try vector(witness.pointB.subtracting(witness.pointA), witness.normal.scaled(by: witness.separation),
                   "Original signed point balance")
        try scalar(witness.normal.magnitude(), 1, "Unit witness normal")
        let policy = try policy()
        try check(witness.originalBalanceResidual <= policy.lengthTolerance &&
                  witness.simplexResidual <= policy.lengthTolerance &&
                  witness.supportIntervalResidual <= policy.lengthTolerance, "Original numerical residual gates")
        try check(witness.separationLowerBound <= expected + 2.2e-8 &&
                  witness.separationUpperBound >= expected - 2.2e-8 &&
                  witness.separationUpperBound-witness.separationLowerBound <= policy.lengthTolerance,
                  "Independent value contained by bounded dual interval")
        let plane = try supportValue(first, witness.normal) + supportValue(second, witness.normal.scaled(by: -1))
        if expected > 0 { try scalar(-plane, witness.separationLowerBound, "Original separating support plane") }
        else if expected < 0 { try scalar(-plane, witness.separationLowerBound, "Original penetration upper support plane") }
        try scalar(witness.approximationError, first.geometry.approximationError+second.geometry.approximationError,
                   "Original source approximation sum")
        try check(witness.iterations > 0, "Actual cumulative algorithm iterations")
    }
}
