import SwiftMechanics

/// Bounded immutable fixture owner retained across the original observer callbacks.
final class ContactRangeProbeContext: Sendable {
    let physical: ContactRangeProbeModel
    let policy: ContactRangeObservationPolicy
    let observer: any ContactRangeObserving
    let mount: ObservationMount

    @inline(never) init(trigger: Bool = false, childMass: Double = 1,
                        rootPose: RigidTransform = .identity,
                        sensorPose: RigidTransform = .identity,
                        observer: any ContactRangeObserving = ReferenceContactRangeObserver()) throws {
        physical = try ContactRangeProbeModel(trigger: trigger, childMass: childMass, rootPose: rootPose)
        policy = try ContactRangeObservationPolicy(
            observation: ObservationPolicy(maximumBodies: 2, maximumCoordinates: 1, maximumReactionRows: 0, maximumMetadataBytes: 16384),
            query: CollisionQueryPolicy(absoluteLengthTolerance: 1e-12, relativeLengthTolerance: 1e-12,
                referenceLength: 1, maximumApproximationError: 0),
            contact: ContactAcceptancePolicy(absoluteEnergyTolerance: 1e-10, absolutePowerTolerance: 1e-10,
                relativeTolerance: 1e-11, referenceEnergy: 1, referencePower: 1, coneTolerance: 1e-11),
            maximumColliders: 2, maximumHits: 2, maximumTactileBindings: 1,
            maximumTriggerRecords: 2, maximumMetadataBytes: 16384)
        self.observer = observer
        mount = try Self.mount(body: physical.root, pose: sensorPose, suffix: "root")
    }

    static func mount(body: EntityID, pose: RigidTransform, suffix: String) throws -> ObservationMount {
        try ObservationMount(sensor: EntityID(kind: .sensor, key: "contact-range-sensor-" + suffix), body: body,
            sensorFrame: EntityID(kind: .frame, key: "contact-range-sensor-frame-" + suffix), sensorToBody: pose)
    }

    static func numericalWork() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 100000, arithmeticOperations: 1000000, iterations: 10000))
    }
    static func collisionWork() throws -> CollisionWork {
        CollisionWork(budget: try CollisionBudget(scalarStorage: 4096, operations: 100000, iterations: 1000, records: 64))
    }
    static func contactWork() throws -> ContactWork {
        ContactWork(budget: try ContactBudget(operations: 100000, scalarStorage: 4096, records: 8))
    }

    @inline(never) func scene(position: Double, velocity: Double = 0, time: Double) throws -> ContactRangeScene {
        let state = try physical.model.makeState(KinematicState(revision: 1, time: time,
            q: [position], v: [velocity], acceleration: [0]))
        var work = try Self.numericalWork()
        let issuer: any ContactRangeScenePreparing = ReferenceContactRangeScenePreparer()
        return try issuer.prepare(model: physical.model, state: state, colliders: physical.colliders,
            revision: 7, policy: policy, work: &work)
    }

    @inline(never) func range(scene: ContactRangeScene, ray: CollisionRay) throws -> RangeObservation {
        var work = try Self.numericalWork(), collision = try Self.collisionWork()
        return try observer.range(scene: scene, mount: mount, ray: ray, targets: [physical.secondCollider],
            policy: policy, collisionWork: &collision, work: &work)
    }
    @inline(never) func trigger(scene: ContactRangeScene, previous: TriggerObservation?, index: UInt64) throws -> TriggerObservation {
        var work = try Self.numericalWork(), collision = try Self.collisionWork()
        return try observer.triggers(scene: scene, mount: mount, filters: CollisionFilterPolicy(jointExclusions: [], allowSameBody: false, user: nil),
            previous: previous, sampleIndex: index, policy: policy, collisionWork: &collision, work: &work)
    }
    @inline(never) func tactile(scene: ContactRangeScene, mount: ObservationMount,
                               binding: TactileContactBinding) throws -> TactileObservation {
        var work = try Self.numericalWork(), collision = try Self.collisionWork(), contact = try Self.contactWork()
        return try observer.tactile(scene: scene, mount: mount, contact: binding, policy: policy,
            collisionWork: &collision, contactWork: &contact, work: &work)
    }

    @inline(never) func binding(time: Double) throws -> TactileContactBinding {
        let pair = try Self.pair()
        let identity = try ContactIdentity(key: "contact-range-law-contact",
            firstBody: ModelReference(id: physical.root, revision: 1), secondBody: ModelReference(id: physical.child, revision: 1),
            frame: ModelReference(id: physical.model.tree.worldFrame, revision: 1),
            firstGeometryRevision: 1, secondGeometryRevision: 1, tangentLayoutRevision: 1)
        var work = try Self.contactWork()
        let laws: any ContactLawEvaluating = CompliantContactEvaluator()
        let accepted = try laws.initialHistory(identity: identity, pair: pair, timeSeconds: time, work: &work)
        return try TactileContactBinding(firstCollider: physical.firstCollider, secondCollider: physical.secondCollider,
            pair: pair, accepted: accepted, tangentLayoutRevision: 1, firstMaterialTangentInCollider: .unitY)
    }

    @inline(never) private static func pair() throws -> ContactLawPair {
        let first = try material("a"), second = try material("b")
        var work = try contactWork()
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        return try pairing.combine(first: first, second: second, selection: .linear(maximumPenetration: 1, maximumNormalSpeed: 100),
            lossPolicy: .compliantDampingOnly, resistanceRadius: 1, override: nil, work: &work)
    }
    private static func material(_ suffix: String) throws -> ContactMaterial {
        try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: "contact-range-material-" + suffix), revision: 1),
            youngModulus: 1e6, poissonsRatio: 0.2, linearStiffness: 2000, normalDamping: 0, huntCrossleyAlpha: 0,
            friction: .none, resistance: ContactResistanceParameters(rollingCoefficient: 0, spinningCoefficient: 0,
                angularRegularization: 0.1), cohesion: .none)
    }
}
