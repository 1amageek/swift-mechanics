import SwiftMechanics

/// Public constitutive sources and genuinely issued history for same-time current sampling.
final class ContactCurrentProbeContext: Sendable {
    private let source: Source
    var pair: ContactLawPair { source.pair }
    var identity: ContactIdentity { source.identity }
    var basis: ContactBasis { source.basis }
    var policy: ContactAcceptancePolicy { source.policy }
    var virgin: ContactHistory { source.virgin }
    let issuedTrial: ContactResponse
    var accepted: ContactHistory { issuedTrial.trialHistory }

    /// Setup records leave the stack before the original positive-interval response call.
    private final class Source: Sendable {
        let pair: ContactLawPair
        let identity: ContactIdentity
        let basis: ContactBasis
        let policy: ContactAcceptancePolicy
        let virgin: ContactHistory

        @inline(never) init(rotation: UnitQuaternion, resistance: ContactResistanceParameters?,
            cohesion: ContactCohesionLaw, revision: UInt64) throws {
            let pair = try ContactCurrentProbeContext.makePair(resistance: resistance, cohesion: cohesion, revision: revision)
            let identity = try ContactCurrentProbeContext.makeIdentity(revision: revision)
            self.pair = pair
            self.identity = identity
            basis = try ContactBasis(frame: identity.frame, contactToQuery: rotation)
            policy = try ContactCurrentProbeContext.makePolicy()
            virgin = try ContactCurrentProbeContext.makeVirgin(identity: identity, pair: pair)
        }
    }

    let normalStiffness: Double = 1000
    let tangentialStiffness: Double = 1000
    let expectedBristle: Double = 0.001
    let expectedNormalForce: Double = 10
    let expectedTangentialForceFirst: Double = -1
    let expectedTangentialStoredEnergy: Double = 0.0005
    let expectedNormalStoredEnergy: Double = 0.05
    let issuanceIntervalSeconds: Double = 1

    @inline(never) init(rotation: UnitQuaternion = .identity,
        resistance: ContactResistanceParameters? = nil, cohesion: ContactCohesionLaw = .none,
        revision: UInt64 = 1) throws {
        let source = try Source(rotation: rotation, resistance: resistance, cohesion: cohesion, revision: revision)
        self.source = source
        issuedTrial = try Self.issueTrial(source)
    }

    static func makeWork(operations: Int = 100_000, scalarStorage: Int = 2048,
                         records: Int = 4) throws(ContactLawError) -> ContactWork {
        ContactWork(budget: try ContactBudget(operations: operations, scalarStorage: scalarStorage, records: records))
    }

    static func makePolicy() throws(ContactLawError) -> ContactAcceptancePolicy {
        try ContactAcceptancePolicy(absoluteEnergyTolerance: 1e-10, absolutePowerTolerance: 1e-10,
            relativeTolerance: 1e-11, referenceEnergy: 1, referencePower: 1, coneTolerance: 1e-11)
    }

    func makeService() -> any ContactCurrentEvaluating { CompliantContactCurrentEvaluator() }

    /// Material-axis velocity is independent input, including arbitrary finite virgin tangent slip.
    @inline(never) func currentInput(useVirginHistory: Bool = false, separation: Double = -0.01,
        materialVelocity: Vector3 = .zero, materialAngularVelocity: Vector3 = .zero) throws -> ContactCurrentInput {
        let history = useVirginHistory ? virgin : accepted
        return try ContactCurrentInput(identity: identity, basis: basis, separation: separation,
            relativeVelocity: basis.contactToQuery.rotating(materialVelocity),
            relativeAngularVelocity: basis.contactToQuery.rotating(materialAngularVelocity),
            timeSeconds: history.timeSeconds)
    }

    /// Original frame mapping of the independent (-1,0,10) loaded-traction oracle.
    func expectedLoadedForce() throws(CoreError) -> Vector3 {
        try basis.contactToQuery.rotating(Vector3(-1, 0, 10))
    }

    @inline(never) private static func makePair(resistance: ContactResistanceParameters?,
        cohesion: ContactCohesionLaw, revision: UInt64) throws -> ContactLawPair {
        let resistance = try resistance ?? ContactResistanceParameters(rollingCoefficient: 0,
            spinningCoefficient: 0, angularRegularization: 0.1)
        let first = try material("current-public-material-a", resistance: resistance, cohesion: cohesion, revision: revision)
        let second = try material("current-public-material-b", resistance: resistance, cohesion: cohesion, revision: revision)
        var work = try makeWork()
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        return try pairing.combine(first: first, second: second,
            selection: .linear(maximumPenetration: 0.1, maximumNormalSpeed: 10),
            lossPolicy: .compliantDampingOnly, resistanceRadius: 0.5, override: nil, work: &work)
    }

    @inline(never) private static func material(_ name: String, resistance: ContactResistanceParameters,
        cohesion: ContactCohesionLaw, revision: UInt64) throws -> ContactMaterial {
        let friction = ContactFrictionLaw.elasticCoulomb(try ContactFrictionParameters(staticFirst: 0.8,
            staticSecond: 0.4, dynamicFirst: 0.4, dynamicSecond: 0.2,
            tangentialStiffness: 2000, transitionSpeed: 0.1))
        return try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: name), revision: revision),
            youngModulus: 1e6, poissonsRatio: 0.25, linearStiffness: 2000, normalDamping: 0,
            huntCrossleyAlpha: 0, friction: friction, resistance: resistance, cohesion: cohesion)
    }

    @inline(never) private static func makeIdentity(revision: UInt64) throws -> ContactIdentity {
        try ContactIdentity(key: "current-public-contact",
            firstBody: ModelReference(id: EntityID(kind: .body, key: "current-public-body-a"), revision: revision),
            secondBody: ModelReference(id: EntityID(kind: .body, key: "current-public-body-b"), revision: revision),
            frame: ModelReference(id: EntityID(kind: .frame, key: "current-public-world"), revision: revision),
            firstGeometryRevision: revision, secondGeometryRevision: revision, tangentLayoutRevision: revision)
    }

    @inline(never) private static func makeVirgin(identity: ContactIdentity, pair: ContactLawPair) throws -> ContactHistory {
        var work = try makeWork()
        let evaluator: any ContactLawEvaluating = CompliantContactEvaluator()
        return try evaluator.initialHistory(identity: identity, pair: pair, timeSeconds: 0, work: &work)
    }

    @inline(never) private static func issueTrial(_ source: Source) throws -> ContactResponse {
        // One real one-second interval issues z1=0.001; it never approximates a current sample.
        let input = try ContactInput(identity: source.identity, basis: source.basis, separation: -0.01,
            relativeVelocity: source.basis.contactToQuery.rotating(Vector3(0.001, 0, 0)), relativeAngularVelocity: .zero,
            startTimeSeconds: source.virgin.timeSeconds, timeStepSeconds: 1)
        var work = try makeWork()
        let evaluator: any ContactLawEvaluating = CompliantContactEvaluator()
        return try evaluator.evaluate(input: input, pair: source.pair, accepted: source.virgin, policy: source.policy, work: &work)
    }
}
