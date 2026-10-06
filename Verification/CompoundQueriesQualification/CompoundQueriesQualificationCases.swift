import SwiftMechanics

public enum CompoundQueriesQualificationCases {
    private typealias F = CompoundQueriesQualificationFixture
    private static func check(_ condition: Bool, _ reason: String) throws {
        guard condition else { throw CompoundQueriesQualificationError.assertion(reason) }
    }
    private static func near(_ value: Double, _ expected: Double, _ reason: String) throws {
        try check(value.isFinite && abs(value - expected) <= 1e-9, reason)
    }
    private static func vector(_ value: Vector3, _ x: Double, _ y: Double, _ z: Double, _ reason: String) throws {
        try near(value.x, x, reason + ".x"); try near(value.y, y, reason + ".y"); try near(value.z, z, reason + ".z")
    }
    private static func required(_ value: CompoundCollisionWitness?) throws -> CompoundCollisionWitness {
        guard let value else { throw CompoundQueriesQualificationError.assertion("missing closest witness") }
        return value
    }
    private static func refused(_ expected: CompoundCollisionError, _ body: () throws -> Void) throws {
        do { try body() } catch let error as CompoundCollisionError {
            try check(error == expected, "typed compound refusal: \(error)"); return
        }
        throw CompoundQueriesQualificationError.assertion("unexpected compound success")
    }
    private static func balance(_ value: CollisionWitness) throws {
        let delta = try value.pointB.subtracting(value.pointA)
        try near(delta.dot(value.normal), value.separation, "original witness normal balance")
        try near(value.normal.magnitude(), 1, "original witness unit normal")
        try near(value.originalBalanceResidual, 0, "original supplier residual")
    }
    private static func ledger(_ work: CollisionWork, _ operations: Int, _ storage: Int) throws {
        try check(work.operations == operations && work.peakScalarStorage == storage && work.iterations == 0,
                  "exact consumed operations / peak scalar slots / zero iterations")
    }

    public static func transformedOriginalWitnesses() throws {
        let rotation = try UnitQuaternion(axis: .unitZ, angle: .pi / 2)
        let a0 = try F.child("a0")
        let a1 = try F.child("a1", pose: F.pose(4), margin: 0.1, deviation: 0.02)
        let b0 = try F.child("b0", body: "B", frame: "LB", shape: .sphere(radius: 0.5), margin: 0.2, deviation: 0.03)
        let a = try F.placement([a1, a0], pose: F.pose(10, -2, 1, rotation: rotation))
        let b = try F.placement([b0], key: "CB", body: "B", frame: "LB", pose: F.pose(10, 1, 1, rotation: rotation))
        var work = try F.work()
        let best = try required(F.service().closest(first: a, second: b, filters: F.filters(), policy: F.policy(), work: &work))
        try check(best.firstLocalChild == a1 && best.secondLocalChild == b0, "original local child values retained")
        try check(best.firstAssembly == a.compound.identity && best.secondAssembly == b.compound.identity, "assembly attribution")
        let w = best.witness
        try vector(w.poseA.translation, 10, 2, 1, "transformed original a1 center")
        try vector(w.poseB.translation, 10, 1, 1, "transformed original b0 center")
        try vector(w.pointA, 10, 0.9, 1, "margin A point")
        try vector(w.pointB, 10, 1.7, 1, "margin B point")
        try vector(w.normal, 0, -1, 0, "world normal"); try near(w.separation, -0.8, "minimum signed separation")
        try near(w.approximationError, 0.05, "original summed child approximation")
        try check(w.pair.first.representation == a1.geometry.representation && w.pair.second.representation == b0.geometry.representation,
                  "source / revision / representation retained")
        try check(w.pair.first.geometryRevision == 11 && w.pair.first.frameRevision == 9 && w.pair.first.frameID == a.frameID,
                  "world identity revisions")
        try balance(w)
        let overlaps = try F.service().overlaps(first: a, second: b, filters: F.filters(), policy: F.policy(), work: &work)
        try check(overlaps.count == 1 && overlaps[0].firstLocalChild == a1, "complete child overlap selection")
        try near(overlaps[0].witness.separation, -0.8, "overlap same literal geometry")
    }

    public static func deterministicPairsAndRays() throws {
        let a1 = try F.child("a1"), a2 = try F.child("a2")
        let b1 = try F.child("b1", body: "B", frame: "LB"), b2 = try F.child("b2", body: "B", frame: "LB")
        let a = try F.placement([a2, a1])
        let b = try F.placement([b2, b1], key: "CB", body: "B", frame: "LB", pose: F.pose(1.5))
        var work = try F.work()
        let best = try required(F.service().closest(first: a, second: b, filters: F.filters(), policy: F.policy(), work: &work))
        try check(best.firstLocalChild == a1 && best.secondLocalChild == b1, "closest lexical tie")
        let overlap = try F.service().overlaps(first: a, second: b, filters: F.filters(), policy: F.policy(), work: &work)
        try check(overlap.map { $0.firstLocalChild.geometry.colliderID.key + $0.secondLocalChild.geometry.colliderID.key }
            == ["a1b1", "a1b2", "a2b1", "a2b2"], "complete original pair ordering")
        let reordered = try F.placement([a1, a2])
        let again = try F.service().overlaps(first: reordered, second: b, filters: F.filters(), policy: F.policy(), work: &work)
        try check(again.map { $0.firstLocalChild.geometry.colliderID } == overlap.map { $0.firstLocalChild.geometry.colliderID },
                  "input permutation preserves ordering")
        let r1 = try F.child("r1"), r2 = try F.child("r2"), r3 = try F.child("r3", pose: F.pose(1), deviation: 0.02)
        let placed = try F.placement([r3, r2, r1], pose: F.pose(5))
        let hits = try F.service().rayHits(placement: placed, ray: F.ray(2), policy: F.policy(), work: &work)
        try check(hits.map { $0.localChild.geometry.colliderID.key } == ["r1", "r2", "r3"], "all child ray ties and ordering")
        try check(hits.count == 3 && hits[0].localChild == r1 && hits[2].localChild == r3, "original ray children retained")
        for (index, distance) in [2.0, 2.0, 3.0].enumerated() {
            try near(hits[index].hit.distance, distance, "literal all-child distance")
            try vector(hits[index].hit.point, 2 + distance, 0, 0, "literal child boundary")
            try vector(hits[index].hit.outwardNormal, -1, 0, 0, "ray original normal")
            try check(hits[index].assembly == placed.compound.identity && hits[index].hit.geometry.frameID == placed.frameID,
                      "ray assembly/world source attribution")
        }
        try near(hits[2].approximationError, 0.02, "ray original quality")
        // The third surface lies inside the union; it must still be returned as a child boundary.
        let miss = try CollisionRay(origin: F.vector(2, 5, 0), direction: .unitX, maximumDistance: 10)
        try check(F.service().rayHits(placement: placed, ray: miss, policy: F.policy(), work: &work).isEmpty, "actual all-child ray miss")
    }

    public static func originalAnalyticFeatures() throws {
        let box = try F.child("b", body: "B", frame: "LB", shape: .box(halfExtents: F.vector(1, 2, 3)))
        let b = try F.placement([box], key: "CB", body: "B", frame: "LB")
        let outside = try F.placement([F.child("a", shape: .sphere(radius: 0.5))], pose: F.pose(3))
        var work = try F.work()
        let w = try required(F.service().closest(first: outside, second: b, filters: F.filters(), policy: F.policy(), work: &work)).witness
        try near(w.separation, 1.5, "sphere-box outside separation")
        try vector(w.pointA, 2.5, 0, 0, "outside sphere point"); try vector(w.pointB, 1, 0, 0, "outside box point")
        try check(w.featureA == .sphere && w.featureB == .boxBoundary(axisMask: 1, positiveMask: 1), "original outside features")
        try balance(w)
        let inside = try F.placement([F.child("a", shape: .sphere(radius: 0.5))])
        let interior = try required(F.service().closest(first: inside, second: b, filters: F.filters(), policy: F.policy(), work: &work)).witness
        try near(interior.separation, -1.5, "interior nearest face")
        try vector(interior.pointA, -0.5, 0, 0, "interior sphere point"); try vector(interior.pointB, 1, 0, 0, "interior box face")
        try check(interior.featureB == .boxFace(axis: 0, positive: true), "original interior tie feature"); try balance(interior)
        let boxA = try F.placement([F.child("a", shape: .box(halfExtents: F.vector(1, 2, 3)))], pose: F.pose(0, 0, 2))
        let planeB = try F.placement([F.child("b", body: "B", frame: "LB", shape: .halfSpace)], key: "CB", body: "B", frame: "LB")
        let plane = try required(F.service().closest(first: boxA, second: planeB, filters: F.filters(), policy: F.policy(), work: &work)).witness
        try near(plane.separation, -1, "box half-space separation")
        try vector(plane.pointA, 1, 2, -1, "original support vertex"); try vector(plane.pointB, 1, 2, 0, "plane projection")
        try check(plane.featureA == .boxVertex(positiveMask: 3) && plane.featureB == .halfSpace, "original box/plane features")
        try balance(plane)
    }

    public static func filtersFidelityAndExplicitRefusal() throws {
        let pair = try F.pair(); var work = try F.work()
        let excluded = try CollisionPairKey(F.id(.collider, "a"), F.id(.collider, "b"))
        try check(F.service().closest(first: pair.0, second: pair.1, filters: F.filters(exclusions: [excluded]), policy: F.policy(), work: &work) == nil,
                  "actual child exclusion")
        let disabled = try F.placement([F.child("a")], filter: F.filter(enabled: false))
        let masked = try F.placement([F.child("a")], filter: F.filter(layer: 2, mask: 2))
        let childDisabled = try F.placement([F.child("a", filter: F.filter(enabled: false))])
        let childMasked = try F.placement([F.child("a", filter: F.filter(layer: 2, mask: 2))])
        for first in [disabled, masked, childDisabled, childMasked] {
            try check(F.service().closest(first: first, second: pair.1, filters: F.filters(), policy: F.policy(), work: &work) == nil,
                      "actual assembly/child enabled and layer filters")
        }
        try check(F.service().rayHits(placement: disabled, ray: F.ray(), policy: F.policy(), work: &work).isEmpty, "disabled assembly ray")
        try check(F.service().rayHits(placement: childDisabled, ray: F.ray(), policy: F.policy(), work: &work).isEmpty, "disabled child ray")
        let same = try F.placement([F.child("b", frame: "LB")], key: "CB", frame: "LB", pose: F.pose(1.5))
        try check(F.service().closest(first: pair.0, second: same, filters: F.filters(), policy: F.policy(), work: &work) == nil, "same body gate")
        try check(F.service().closest(first: pair.0, second: same, filters: F.filters(sameBody: true), policy: F.policy(), work: &work) != nil,
                  "explicit same body permission")
        try refused(.unsupportedUserFilterAccounting) {
            _ = try F.service().closest(first: disabled, second: pair.1,
                filters: F.filters(user: CompoundQueriesQualificationUnexpectedFilter()), policy: F.policy(), work: &work)
        }
        let missing = try CollisionPairKey(F.id(.collider, "a"), F.id(.collider, "missing"))
        try refused(.collision(.invalidReference)) {
            _ = try F.service().closest(first: disabled, second: pair.1, filters: F.filters(exclusions: [missing]), policy: F.policy(), work: &work)
        }
        try refused(.invalidIdentity) {
            _ = try F.service().overlaps(first: disabled, second: pair.1, filters: F.filters(exclusions: [excluded, excluded]), policy: F.policy(), work: &work)
        }
        let coarse = try F.placement([F.child("a", deviation: 0.02, filter: F.filter(enabled: false))])
        try refused(.child(first: F.id(.collider, "a"), second: nil, cause: .approximationExceeded(value: 0.02, maximum: 0.015))) {
            _ = try F.service().closest(first: coarse, second: pair.1, filters: F.filters(), policy: F.policy(maximumError: 0.015), work: &work)
        }
    }

    public static func admissionAndMetadataBoundaries() throws {
        let child = try F.child("a"); var work = try F.work()
        let shape = try F.shape([child], metadata: 32, work: &work)
        try check(shape.metadataBytes == 32, "literal UTF8 metadata count"); try ledger(work, 64, 416)
        let placed = try CompoundCollisionPlacement(compound: shape, expectedRevision: 7, frameID: F.id(.frame, "W"),
            frameRevision: 9, pose: .identity, filter: F.filter(),
            policy: CompoundCollisionPolicy(maximumChildren: 1, maximumMetadataBytes: 33), work: &work)
        try check(placed.compound.children == [child], "publication retains exact original child"); try ledger(work, 81, 416)
        var tight = try F.work()
        try refused(.metadataLimit(limit: 31)) { _ = try F.shape([child], metadata: 31, work: &tight) }
        try ledger(tight, 32, 416)
        var placementWork = try F.work()
        try refused(.metadataLimit(limit: 32)) {
            _ = try CompoundCollisionPlacement(compound: shape, expectedRevision: 7, frameID: F.id(.frame, "W"),
                frameRevision: 9, pose: .identity, filter: F.filter(),
                policy: CompoundCollisionPolicy(maximumChildren: 1, maximumMetadataBytes: 32), work: &placementWork)
        }
        try ledger(placementWork, 17, 0)
        for children in [[], [child, child]] {
            try refused(children.isEmpty ? .invalidChildren : .invalidIdentity) { _ = try F.shape(children, work: &work) }
        }
        try refused(.invalidChildren) { _ = try F.shape([child, F.child("a2")], maximumChildren: 1, work: &work) }
        try refused(.invalidIdentity) { _ = try F.shape([F.child("CA")], work: &work) }
        try refused(.invalidIdentity) { _ = try F.shape([F.child("a", body: "B")], work: &work) }
        try refused(.invalidIdentity) { _ = try F.shape([F.child("a", frame: "LB")], work: &work) }
        try refused(.invalidIdentity) { _ = try F.shape([F.child("a", frameRevision: 4)], work: &work) }
        for unit in [SIUnits.millimetre, SIUnits.second] {
            try refused(.invalidUnit) { _ = try F.shape([child], unit: unit, work: &work) }
        }
        try refused(.staleRevision(expected: 8, actual: 7)) {
            _ = try CompoundCollisionPlacement(compound: shape, expectedRevision: 8, frameID: F.id(.frame, "W"),
                frameRevision: 9, pose: .identity, filter: F.filter(),
                policy: CompoundCollisionPolicy(maximumChildren: 1, maximumMetadataBytes: 33), work: &work)
        }
        let a = try F.placement([child])
        let cross = try F.placement([F.child("a", body: "B", frame: "LB")], key: "CB", body: "B", frame: "LB")
        try refused(.invalidIdentity) { _ = try F.service().closest(first: a, second: cross, filters: F.filters(), policy: F.policy(), work: &work) }
        let otherAssemblyChild = try F.placement([F.child("CB")])
        let pair = try F.pair()
        try refused(.invalidIdentity) { _ = try F.service().closest(first: otherAssemblyChild, second: pair.1, filters: F.filters(), policy: F.policy(), work: &work) }
        for b in [try F.placement([F.child("b", body: "B", frame: "LB")], key: "CB", body: "B", frame: "LB", world: "other"),
                  try F.placement([F.child("b", body: "B", frame: "LB")], key: "CB", body: "B", frame: "LB", worldRevision: 10)] {
            try refused(.frameMismatch) { _ = try F.service().overlaps(first: a, second: b, filters: F.filters(), policy: F.policy(), work: &work) }
        }
        let huge = try F.placement([F.child("a", pose: F.pose(Double.greatestFiniteMagnitude))], pose: F.pose(Double.greatestFiniteMagnitude))
        try refused(.core(.nonFiniteResult)) { _ = try F.service().closest(first: huge, second: pair.1, filters: F.filters(), policy: F.policy(), work: &work) }
    }

    public static func exactWorkAndResourceBoundaries() throws {
        let pair = try F.pair(); var work = try F.work(operations: 17_520, storage: 1_600, records: 1)
        _ = try required(F.service().closest(first: pair.0, second: pair.1, filters: F.filters(), policy: F.policy(), work: &work))
        try ledger(work, 4_400, 1_600)
        let overlap = try F.service().overlaps(first: pair.0, second: pair.1, filters: F.filters(), policy: F.policy(), work: &work)
        try check(overlap.count == 1, "one original overlap"); try ledger(work, 9_056, 1_600)
        let hits = try F.service().rayHits(placement: pair.0, ray: F.ray(), policy: F.policy(), work: &work)
        try check(hits.count == 1, "one original ray hit"); try ledger(work, 17_520, 1_600)
        var rayWork = try F.work(operations: 8_464, storage: 1_440, records: 1)
        _ = try F.service().rayHits(placement: pair.0, ray: F.ray(), policy: F.policy(), work: &rayWork)
        try ledger(rayWork, 8_464, 1_440)
        var operations = try F.work(operations: 4_399)
        try refused(.child(first: F.id(.collider, "a"), second: F.id(.collider, "b"),
            cause: .resourceLimit(resource: .operations, limit: 4_399))) {
            _ = try F.service().closest(first: pair.0, second: pair.1, filters: F.filters(), policy: F.policy(), work: &operations)
        }
        try ledger(operations, 304, 1_600)
        var records = try F.work(records: 0)
        try refused(.child(first: F.id(.collider, "a"), second: F.id(.collider, "b"),
            cause: .resourceLimit(resource: .records, limit: 0))) {
            _ = try F.service().closest(first: pair.0, second: pair.1, filters: F.filters(), policy: F.policy(), work: &records)
        }
        try ledger(records, 304, 1_600)
        var storage = try F.work(storage: 1_599)
        try refused(.collision(.resourceLimit(resource: .scalarStorage, limit: 1_599))) {
            _ = try F.service().closest(first: pair.0, second: pair.1, filters: F.filters(), policy: F.policy(), work: &storage)
        }
        try ledger(storage, 16, 576)
        var zero = try F.work(operations: 0)
        try refused(.collision(.resourceLimit(resource: .operations, limit: 0))) {
            _ = try F.service().closest(first: pair.0, second: pair.1, filters: F.filters(), policy: F.policy(), work: &zero)
        }
        try ledger(zero, 0, 576)
    }

    public static func transactionalLateRefusals() throws {
        let pair = try F.pair(); var work = try F.work()
        let original = try F.service().overlaps(first: pair.0, second: pair.1, filters: F.filters(), policy: F.policy(), work: &work)
        var published = original
        let first = try F.placement([F.child("a1"), F.child("a2", shape: .box(halfExtents: F.vector(1, 1, 1)))])
        let second = try F.placement([F.child("b", body: "B", frame: "LB", shape: .box(halfExtents: F.vector(1, 1, 1)))], key: "CB", body: "B", frame: "LB")
        try refused(.child(first: F.id(.collider, "a2"), second: F.id(.collider, "b"), cause: .unsupportedPair)) {
            published = try F.service().overlaps(first: first, second: second, filters: F.filters(), policy: F.policy(), work: &work)
        }
        try check(published.count == 1 && published[0].firstLocalChild == original[0].firstLocalChild, "later unsupported pair preserves caller result")
        try refused(.child(first: F.id(.collider, "a2"), second: F.id(.collider, "b"), cause: .unsupportedPair)) {
            _ = try F.service().closest(first: first, second: second, filters: F.filters(), policy: F.policy(), work: &work)
        }
        let twins = try F.placement([F.child("a2"), F.child("a1")])
        var cap = try F.work(records: 1)
        try refused(.collision(.resourceLimit(resource: .records, limit: 1))) {
            published = try F.service().overlaps(first: twins, second: pair.1, filters: F.filters(), policy: F.policy(), work: &cap)
        }
        try check(published.count == 1 && published[0].firstLocalChild == original[0].firstLocalChild, "later overlap cap preserves result")
        // 24 cross-ID admission +384 transforms +2*(32 filter+4096 witness)+256 first append.
        try ledger(cap, 8_920, 1_760)
        var hitWork = try F.work(records: 1)
        var hits = try F.service().rayHits(placement: pair.0, ray: F.ray(), policy: F.policy(), work: &work)
        try refused(.collision(.resourceLimit(resource: .records, limit: 1))) {
            hits = try F.service().rayHits(placement: twins, ray: F.ray(), policy: F.policy(), work: &hitWork)
        }
        try check(hits.count == 1 && hits[0].localChild.geometry.colliderID.key == "a", "later ray cap preserves result")
        // 256 transforms +2*(16 loop+8192 original ray) +128 first hit insertion.
        try ledger(hitWork, 16_800, 1_600)
        let rounded = try F.placement([F.child("a", shape: .box(halfExtents: F.vector(1, 1, 1)), margin: 0.1)])
        try refused(.child(first: F.id(.collider, "a"), second: nil, cause: .unsupportedQuery)) {
            _ = try F.service().rayHits(placement: rounded, ray: F.ray(), policy: F.policy(), work: &work)
        }
    }

    public static func cancelledTask(first: CompoundCollisionPlacement, second: CompoundCollisionPlacement) throws {
        try check(Task.isCancelled, "actual task cancelled before public operation")
        var work = try F.work()
        try refused(.collision(.cancelled)) {
            _ = try F.service().closest(first: first, second: second, filters: F.filters(), policy: F.policy(), work: &work)
        }
        try ledger(work, 0, 0)
        try refused(.collision(.cancelled)) {
            _ = try F.service().overlaps(first: first, second: second, filters: F.filters(), policy: F.policy(), work: &work)
        }
        try refused(.collision(.cancelled)) {
            _ = try F.service().rayHits(placement: first, ray: F.ray(), policy: F.policy(), work: &work)
        }
        try ledger(work, 0, 0)
    }
}
