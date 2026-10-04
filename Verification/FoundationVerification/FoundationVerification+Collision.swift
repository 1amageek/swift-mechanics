import SwiftMechanics

extension FoundationVerification {
    static func verifyCollision() throws {
        let policy = try CollisionQueryPolicy(absoluteLengthTolerance: 1e-10, relativeLengthTolerance: 1e-11,
            referenceLength: 1, maximumApproximationError: 0)
        var work = CollisionWork(budget: try CollisionBudget(scalarStorage: 10000,
            operations: 1_000_000, iterations: 100, records: 10))
        let geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        let a = try collisionProxy("probe-a", shape: .sphere(radius: 1), position: .zero)
        let b = try collisionProxy("probe-b", shape: .sphere(radius: 1), position: Vector3(3,0,0))
        let witness = try geometry.witness(first: a, second: b, policy: policy, work: &work)
        guard witness.separation == 1, witness.normal == .unitX,
              witness.pointA == .unitX, witness.pointB == (try Vector3(2,0,0)) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let box = try collisionProxy("probe-box", shape: .box(halfExtents: Vector3(1,1,1)), position: .zero)
        let inside = try geometry.witness(first: a, second: box, policy: policy, work: &work)
        guard inside.separation == -2, inside.pointB == .unitX else { throw FoundationVerificationError.analyticCheckFailed }
        let overlapping = try b.moved(to: RigidTransform(rotation: .identity, translation: Vector3(1.5,0,0)))
        let discovery: any CollisionDiscovering = ExhaustiveCollisionDiscovery()
        let filters = CollisionFilterPolicy(jointExclusions: [], allowSameBody: false, user: nil)
        let candidates = try discovery.candidates(snapshot: CollisionSnapshot(proxies: [overlapping,a], revision: 1),
            endpoint: nil, filters: filters, policy: policy, work: &work)
        guard candidates == [try CollisionPairKey(a.geometry.colliderID,b.geometry.colliderID)] else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let plane = try collisionProxy("probe-plane", shape: .halfSpace, position: .zero)
        let low = try a.moved(to: RigidTransform(rotation: .identity, translation: Vector3(0,0,0.5)))
        let lowWitness = try geometry.witness(first: low, second: plane, policy: policy, work: &work)
        let persistence: any CollisionPersisting = ValueCollisionPersistence()
        let manifoldPolicy = try CollisionManifoldPolicy(mergeDistance: 0.01, breakingSeparation: 0.1)
        let manifold = try persistence.manifold(first: low, second: plane, current: [lowWitness], previous: nil,
            manifoldPolicy: manifoldPolicy, queryPolicy: policy, work: &work)
        let shifted = try low.moved(to: RigidTransform(rotation: .identity, translation: Vector3(2,0,0.5)))
        let shiftedWitness = try geometry.witness(first: shifted, second: plane, policy: policy, work: &work)
        let continued = try persistence.manifold(first: shifted, second: plane, current: [shiftedWitness], previous: manifold,
            manifoldPolicy: manifoldPolicy, queryPolicy: policy, work: &work)
        guard manifold.contacts.count == 1, continued.contacts.count == 1,
              manifold.contacts[0].id == continued.contacts[0].id else { throw FoundationVerificationError.analyticCheckFailed }
        let high = try a.moved(to: RigidTransform(rotation: .identity, translation: Vector3(0,0,5)))
        let end = try a.moved(to: RigidTransform(rotation: .identity, translation: Vector3(0,0,-5)))
        let planeEnd = plane.moved(to: RigidTransform(rotation: .identity, translation: .unitZ))
        let sweeper: any CollisionSweeping = TranslationCollisionSweeper()
        guard let toi = try sweeper.timeOfImpact(first: CollisionSweep(start: high, end: end),
            second: CollisionSweep(start: plane, end: planeEnd), durationSeconds: 1,
            maximumTimeWidthSeconds: 1e-8, policy: policy, work: &work),
              toi.lowerTime <= 4.0 / 11, toi.upperTime >= 4.0 / 11,
              toi.upperTime - toi.lowerTime <= 1e-8,
              toi.lowerSeparation > 0, toi.upperSeparation <= 0 else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        var unsupportedRejected = false
        let otherBox = try collisionProxy("probe-other-box", shape: .box(halfExtents: Vector3(1,1,1)), position: .zero)
        do throws(CollisionError) {
            _ = try geometry.witness(first: box, second: otherBox, policy: policy, work: &work)
        } catch {
            guard error == .unsupportedPair else { throw FoundationVerificationError.analyticCheckFailed }
            unsupportedRejected = true
        }
        guard unsupportedRejected else { throw FoundationVerificationError.analyticCheckFailed }
    }

    private static func collisionProxy(_ key: String, shape: CollisionShape, position: Vector3) throws -> CollisionProxy {
        let source = try SourceProvenance(source: "analytic-runtime-probe", revision: 1)
        let representation = try GeometryRepresentation(kind: .collisionGeometry, assetKey: key,
            provenance: source, quality: .exact)
        return try CollisionProxy(colliderID: EntityID(kind: .collider, key: key),
            bodyID: EntityID(kind: .body, key: key + "-body"), frameID: EntityID(kind: .frame, key: "collision-probe-world"),
            geometryRevision: 1, frameRevision: 1, shape: shape, margin: 0,
            representations: BodyRepresentations(collisionGeometry: representation), expectedSourceRevision: 1,
            resolution: .analytic, pose: RigidTransform(rotation: .identity, translation: position),
            filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false))
    }
}
