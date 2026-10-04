import SwiftMechanics

enum CollisionFixtures {
    static func proxy(_ key: String, shape: CollisionShape, position: Vector3 = .zero,
                      rotation: UnitQuaternion = .identity, margin: Double = 0, body: String? = nil,
                      geometryRevision: UInt64 = 1, sourceRevision: UInt64 = 1, frameRevision: UInt64 = 1,
                      quality: RepresentationQuality = .exact, trigger: Bool = false,
                      layer: UInt64 = 1, mask: UInt64 = .max, enabled: Bool = true,
                      displayKey: String? = nil) throws -> CollisionProxy {
        let provenance = try SourceProvenance(source:"fixture",revision:sourceRevision)
        let collision = try GeometryRepresentation(kind:.collisionGeometry,assetKey:"analytic",provenance:provenance,quality:quality)
        let display: GeometryRepresentation?
        if let displayKey { display = try GeometryRepresentation(kind:.displayGeometry,assetKey:displayKey,provenance:provenance,quality:.exact) }
        else { display = nil }
        return try CollisionProxy(colliderID:EntityID(kind:.collider,key:key),
            bodyID:EntityID(kind:.body,key:body ?? key),frameID:EntityID(kind:.frame,key:"world"),
            geometryRevision:geometryRevision,frameRevision:frameRevision,shape:shape,margin:margin,
            representations:BodyRepresentations(displayGeometry:display,collisionGeometry:collision),
            expectedSourceRevision:sourceRevision,resolution:.analytic,
            pose:RigidTransform(rotation:rotation,translation:position),
            filter:ColliderFilter(enabled:enabled,layerBits:layer,maskBits:mask,isTrigger:trigger))
    }

    static func policy(maximumError: Double = 0.2) throws -> CollisionQueryPolicy {
        try CollisionQueryPolicy(absoluteLengthTolerance:1e-10,relativeLengthTolerance:1e-11,
            referenceLength:1,maximumApproximationError:maximumError)
    }

    static func work(records: Int = 64, storage: Int = 200000, operations: Int = 2_000_000, iterations: Int = 100) throws -> CollisionWork {
        CollisionWork(budget:try CollisionBudget(scalarStorage:storage,operations:operations,iterations:iterations,records:records))
    }

    static func filters(exclusions: [CollisionPairKey] = [], sameBody: Bool = true,
                        user: (any CollisionUserFiltering)? = nil) -> CollisionFilterPolicy {
        CollisionFilterPolicy(jointExclusions:exclusions,allowSameBody:sameBody,user:user)
    }

    static func close(_ a: Double,_ b: Double,absolute:Double = 1e-10) -> Bool { abs(a-b) <= absolute+1e-11*abs(b) }
    static func vectorClose(_ a: Vector3,_ b: Vector3) throws -> Bool { try a.subtracting(b).magnitude() <= 1.1e-10 }
    static func moved(_ proxy: CollisionProxy,_ p: Vector3) -> CollisionProxy {
        proxy.moved(to:RigidTransform(rotation:proxy.pose.rotation,translation:p))
    }
}
