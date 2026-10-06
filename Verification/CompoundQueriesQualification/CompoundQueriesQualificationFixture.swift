import SwiftMechanics

public enum CompoundQueriesQualificationFixture {
    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID {
        try EntityID(kind: kind, key: key)
    }
    public static func vector(_ x: Double, _ y: Double = 0, _ z: Double = 0) throws -> Vector3 {
        try Vector3(x, y, z)
    }
    public static func pose(_ x: Double = 0, _ y: Double = 0, _ z: Double = 0,
                            rotation: UnitQuaternion = .identity) throws -> RigidTransform {
        RigidTransform(rotation: rotation, translation: try vector(x, y, z))
    }
    public static func filter(enabled: Bool = true, layer: UInt64 = 1, mask: UInt64 = 1) -> ColliderFilter {
        ColliderFilter(enabled: enabled, layerBits: layer, maskBits: mask, isTrigger: false)
    }
    public static func work(operations: Int = 20_000_000, storage: Int = 200_000,
                            records: Int = 128) throws -> CollisionWork {
        CollisionWork(budget: try CollisionBudget(scalarStorage: storage, operations: operations,
                                                  iterations: 4, records: records))
    }
    public static func policy(maximumError: Double = 0.1) throws -> CollisionQueryPolicy {
        try CollisionQueryPolicy(absoluteLengthTolerance: 1e-10, relativeLengthTolerance: 1e-11,
                                 referenceLength: 1, maximumApproximationError: maximumError)
    }
    public static func filters(exclusions: [CollisionPairKey] = [], sameBody: Bool = false,
                               user: (any CollisionUserFiltering)? = nil) -> CollisionFilterPolicy {
        CollisionFilterPolicy(jointExclusions: exclusions, allowSameBody: sameBody, user: user)
    }
    public static func service() -> any CompoundCollisionQuerying {
        BoundedCompoundCollisionQueries(geometry: AnalyticCollisionQueries())
    }
    public static func child(_ key: String, body: String = "A", frame: String = "LA", frameRevision: UInt64 = 3,
                             shape: CollisionShape = .sphere(radius: 1), pose: RigidTransform = .identity,
                             margin: Double = 0, deviation: Double = 0,
                             filter: ColliderFilter? = nil) throws -> CollisionProxy {
        let source = try SourceProvenance(source: key + "Source", revision: 5)
        let representation = try GeometryRepresentation(kind: .collisionGeometry, assetKey: key + "Asset",
            provenance: source, quality: deviation == 0 ? .exact : .approximation(maximumDeviationMeters: deviation))
        return try CollisionProxy(colliderID: id(.collider, key), bodyID: id(.body, body), frameID: id(.frame, frame),
            geometryRevision: 11, frameRevision: frameRevision, shape: shape, margin: margin,
            representations: BodyRepresentations(collisionGeometry: representation), expectedSourceRevision: 5,
            resolution: .analytic, pose: pose, filter: filter ?? self.filter())
    }
    public static func identity(_ key: String = "CA", body: String = "A", frame: String = "LA") throws -> CompoundCollisionIdentity {
        try CompoundCollisionIdentity(colliderID: id(.collider, key), bodyID: id(.body, body),
            localFrameID: id(.frame, frame), localFrameRevision: 3, revision: 7,
            provenance: SourceProvenance(source: "assembly" + body, revision: 2))
    }
    public static func shape(_ children: [CollisionProxy], key: String = "CA", body: String = "A",
                             frame: String = "LA", unit: UnitDefinition = SIUnits.metre,
                             metadata: Int = 10_000, maximumChildren: Int = 16,
                             work: inout CollisionWork) throws -> CompoundCollisionShape {
        try CompoundCollisionShape(identity: identity(key, body: body, frame: frame), lengthUnit: unit,
            children: children, policy: CompoundCollisionPolicy(maximumChildren: maximumChildren,
                maximumMetadataBytes: metadata), work: &work)
    }
    public static func placement(_ children: [CollisionProxy], key: String = "CA", body: String = "A",
                                 frame: String = "LA", world: String = "W", worldRevision: UInt64 = 9,
                                 pose: RigidTransform = .identity, filter: ColliderFilter? = nil) throws -> CompoundCollisionPlacement {
        var ledger = try work()
        let compound = try shape(children, key: key, body: body, frame: frame, work: &ledger)
        return try CompoundCollisionPlacement(compound: compound, expectedRevision: 7, frameID: id(.frame, world),
            frameRevision: worldRevision, pose: pose, filter: filter ?? self.filter(),
            policy: CompoundCollisionPolicy(maximumChildren: 16, maximumMetadataBytes: 10_000), work: &ledger)
    }
    public static func pair(distance: Double = 1.5) throws -> (CompoundCollisionPlacement, CompoundCollisionPlacement) {
        (try placement([child("a")]),
         try placement([child("b", body: "B", frame: "LB")], key: "CB", body: "B", frame: "LB", pose: pose(distance)))
    }
    public static func ray(_ origin: Double = -3) throws -> CollisionRay {
        try CollisionRay(origin: vector(origin), direction: vector(1), maximumDistance: 10)
    }
}
