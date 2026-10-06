import SwiftMechanics

public enum TriangleMeshesQualificationFixture {
    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
    public static func vector(_ x: Double, _ y: Double = 0, _ z: Double = 0) throws -> Vector3 { try Vector3(x, y, z) }
    public static func pose(_ x: Double = 0, _ y: Double = 0, _ z: Double = 0,
                            rotation: UnitQuaternion = .identity) throws -> RigidTransform {
        RigidTransform(rotation: rotation, translation: try vector(x, y, z))
    }
    public static func work(operations: Int = 20_000_000, storage: Int = 100_000,
                            records: Int = 1_000, iterations: Int = 128) throws -> CollisionWork {
        CollisionWork(budget: try CollisionBudget(scalarStorage: storage, operations: operations,
            iterations: iterations, records: records))
    }
    public static func policy(maximumError: Double = 0.1) throws -> CollisionQueryPolicy {
        try CollisionQueryPolicy(absoluteLengthTolerance: 1e-9, relativeLengthTolerance: 1e-10,
            referenceLength: 1, maximumApproximationError: maximumError)
    }
    public static func service() -> any TriangleMeshQuerying { HierarchicalTriangleMeshQueries() }
    public static func vertices(height: Double = 0) throws -> [Vector3] {
        try [vector(0, 0, height), vector(2, 0, height), vector(0, 2, height)]
    }
    public static func face(_ id: UInt64 = 41, _ a: Int = 0, _ b: Int = 1, _ c: Int = 2) -> TriangleMeshFace {
        TriangleMeshFace(id: id, a: a, b: b, c: c)
    }
    public static func representation(revision: UInt64 = 7, source: String = "triangleSource",
                                      deviation: Double = 0) throws -> GeometryRepresentation {
        try GeometryRepresentation(kind: .collisionGeometry, assetKey: "triangleAsset",
            provenance: SourceProvenance(source: source, revision: revision),
            quality: deviation == 0 ? .exact : .approximation(maximumDeviationMeters: deviation))
    }
    public static func mesh(vertices: [Vector3], faces: [TriangleMeshFace],
                            distancePolicy: TriangleMeshDistancePolicy = .unsignedSurface,
                            representation: GeometryRepresentation? = nil, expectedSourceRevision: UInt64 = 7,
                            collider: EntityID? = nil, pose: RigidTransform = .identity,
                            work: inout CollisionWork) throws -> TriangleMesh {
        try TriangleMesh(colliderID: collider ?? id(.collider, "mesh"), bodyID: id(.body, "meshBody"),
            frameID: id(.frame, "W"), geometryRevision: 11, frameRevision: 9, vertices: vertices,
            faces: faces, distancePolicy: distancePolicy,
            representations: BodyRepresentations(collisionGeometry: representation ?? self.representation()),
            expectedSourceRevision: expectedSourceRevision, pose: pose, work: &work)
    }
    public static func triangle(deviation: Double = 0) throws -> TriangleMesh {
        var ledger = try work()
        return try mesh(vertices: vertices(), faces: [face()], representation: representation(deviation: deviation), work: &ledger)
    }
    public static func square() throws -> TriangleMesh {
        var ledger = try work()
        return try mesh(vertices: [vector(0), vector(2), vector(2, 2), vector(0, 2)],
            faces: [face(90, 0, 1, 2), face(10, 0, 2, 3)], work: &ledger)
    }
    public static func tetrahedron() throws -> TriangleMesh {
        var ledger = try work()
        return try mesh(vertices: [vector(0), vector(2), vector(0, 2), vector(0, 0, 2)],
            faces: [face(10, 0, 2, 1), face(20, 0, 1, 3), face(30, 0, 3, 2), face(40, 1, 2, 3)],
            distancePolicy: .certifiedTetrahedralSolid, work: &ledger)
    }
    public static func sphere(position: Vector3, radius: Double = 0.5, margin: Double = 0,
                              deviation: Double = 0, frame: String = "W",
                              shape: CollisionShape? = nil) throws -> CollisionProxy {
        let repr = try GeometryRepresentation(kind: .collisionGeometry, assetKey: "sphereAsset",
            provenance: SourceProvenance(source: "sphereSource", revision: 4),
            quality: deviation == 0 ? .exact : .approximation(maximumDeviationMeters: deviation))
        return try CollisionProxy(colliderID: id(.collider, "sphere"), bodyID: id(.body, "sphereBody"),
            frameID: id(.frame, frame), geometryRevision: 13, frameRevision: 9,
            shape: shape ?? .sphere(radius: radius), margin: margin,
            representations: BodyRepresentations(collisionGeometry: repr), expectedSourceRevision: 4,
            resolution: .analytic, pose: RigidTransform(rotation: .identity, translation: position),
            filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false))
    }
    public static func sphereSweep(x: Double = 0.5, y: Double = 0.5, startZ: Double = 3, endZ: Double = -1,
                                   radius: Double = 0.5, margin: Double = 0, deviation: Double = 0) throws -> CollisionSweep {
        let start = try sphere(position: vector(x, y, startZ), radius: radius, margin: margin, deviation: deviation)
        return try CollisionSweep(start: start, end: start.moved(to: pose(x, y, endZ)))
    }
    public static func staticSweep(_ mesh: TriangleMesh) throws -> TriangleMeshSweep { try TriangleMeshSweep(start: mesh, end: mesh) }
    public static func ray(_ x: Double = 0.5, _ y: Double = 0.5, _ z: Double = 3,
                           direction: Vector3 = .unitZ, maximum: Double = 10) throws -> CollisionRay {
        try CollisionRay(origin: vector(x, y, z), direction: direction, maximumDistance: maximum)
    }
}
