import SwiftMechanics

public enum HeightfieldsQualificationFixtures {
    public static func work(operations: Int = 2_000_000, storage: Int = 200_000,
                            records: Int = 128) throws -> CollisionWork {
        CollisionWork(budget: try CollisionBudget(scalarStorage: storage, operations: operations,
                                                 iterations: 100, records: records))
    }

    public static func policy(error: Double = 0.2, edge: Double = 10) throws -> HeightfieldQueryPolicy {
        try HeightfieldQueryPolicy(geometry: CollisionQueryPolicy(absoluteLengthTolerance: 1e-10,
            relativeLengthTolerance: 1e-11, referenceLength: 1, maximumApproximationError: error),
            maximumTriangleEdgeMeters: edge)
    }

    public static func representation(revision: UInt64 = 1, source: String = "original-grid",
                                      quality: RepresentationQuality = .exact) throws -> GeometryRepresentation {
        try GeometryRepresentation(kind: .collisionGeometry, assetKey: "terrain-proxy",
            provenance: SourceProvenance(source: source, revision: revision), quality: quality)
    }

    public static func field(heights: [Double] = [0,0,0,0], rows: Int = 2, columns: Int = 2,
                             spacingX: Double = 1, spacingY: Double = 1, origin: Vector3 = .zero,
                             diagonal: HeightfieldDiagonal = .lowerLeftToUpperRight,
                             motion: HeightfieldMotion = .staticSurface, pose: RigidTransform = .identity,
                             quality: RepresentationQuality = .exact,
                             sourceRevision: UInt64 = 1, expectedSource: UInt64 = 1,
                             work: inout CollisionWork) throws -> GridHeightfield {
        try GridHeightfield(colliderID: EntityID(kind: .collider, key: "terrain"),
            bodyID: EntityID(kind: .body, key: "terrain-body"), frameID: EntityID(kind: .frame, key: "world"),
            frameRevision: 1, geometryRevision: 1, rows: rows, columns: columns,
            spacingX: spacingX, spacingY: spacingY, origin: origin, heights: heights, diagonal: diagonal,
            representation: representation(revision: sourceRevision, quality: quality),
            expectedSourceRevision: expectedSource, motion: motion, pose: pose, work: &work)
    }

    public static func proxy(center: Vector3, shape: CollisionShape = .sphere(radius: 1),
                             margin: Double = 0.25, frameRevision: UInt64 = 1,
                             quality: RepresentationQuality = .exact) throws -> CollisionProxy {
        try CollisionProxy(colliderID: EntityID(kind: .collider, key: "probe"),
            bodyID: EntityID(kind: .body, key: "probe-body"), frameID: EntityID(kind: .frame, key: "world"),
            geometryRevision: 1, frameRevision: frameRevision, shape: shape, margin: margin,
            representations: BodyRepresentations(collisionGeometry: representation(quality: quality)),
            expectedSourceRevision: 1, resolution: .analytic,
            pose: RigidTransform(rotation: .identity, translation: center),
            filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: .max, isTrigger: false))
    }

    public static func check(_ value: Bool, _ message: String) throws {
        guard value else { throw HeightfieldsQualificationError.assertion(message) }
    }

    public static func scalar(_ actual: Double, _ expected: Double, _ message: String) throws {
        try check(actual.isFinite && abs(actual - expected) <= 2e-10 + 1e-11*abs(expected), message)
    }

    public static func vector(_ actual: Vector3, _ x: Double, _ y: Double, _ z: Double,
                              _ message: String) throws {
        try scalar(actual.x, x, message + " x"); try scalar(actual.y, y, message + " y")
        try scalar(actual.z, z, message + " z")
    }

    public static func refuses(_ expected: HeightfieldError,
                               _ operation: () throws -> Void) throws {
        do { try operation() }
        catch let error as HeightfieldError { try check(error == expected, "Wrong heightfield failure"); return }
        catch { throw HeightfieldsQualificationError.assertion("Unexpected supplier error") }
        throw HeightfieldsQualificationError.assertion("Expected heightfield failure")
    }
}
