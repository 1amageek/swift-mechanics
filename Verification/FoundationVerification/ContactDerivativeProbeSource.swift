import SwiftMechanics

/// Original constitutive sources with fixed SI inputs and producer-issued history.
struct ContactDerivativeProbeSource: Sendable {
    let input: ContactInput
    let pair: ContactLawPair
    let accepted: ContactHistory
    let direction: ContactDirection
    let impactPair: ContactLawPair
    let impactDirection: ContactImpactDirection
    let approachSpeed: Double = 2
    let incomingNormalEnergy: Double = 4

    @inline(never)
    init(friction: ContactFrictionLaw = .none, work: inout ContactWork) throws {
        let first = try Self.material("derivative-material-a", friction: friction)
        let second = try Self.material("derivative-material-b", friction: friction)
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        let pair = try pairing.combine(first: first, second: second,
            selection: .linear(maximumPenetration: 0.1, maximumNormalSpeed: 10),
            lossPolicy: .compliantDampingOnly, resistanceRadius: 0.5, override: nil, work: &work)
        self.pair = pair
        impactPair = try pairing.combine(first: first, second: second,
            selection: .hertz(effectiveRadius: 0.1, maximumPenetration: 0.01, maximumNormalSpeed: 10),
            lossPolicy: .separateImpact(restitution: 0.6, thresholdSpeed: 1), resistanceRadius: 0.5,
            override: nil, work: &work)
        let identity = try ContactIdentity(key: "normal-derivative-public",
            firstBody: ModelReference(id: EntityID(kind: .body, key: "derivative-body-a"), revision: 1),
            secondBody: ModelReference(id: EntityID(kind: .body, key: "derivative-body-b"), revision: 1),
            frame: ModelReference(id: EntityID(kind: .frame, key: "derivative-world"), revision: 1),
            firstGeometryRevision: 1, secondGeometryRevision: 1, tangentLayoutRevision: 1)
        input = try ContactInput(identity: identity, basis: ContactBasis(frame: identity.frame, contactToQuery: .identity),
            separation: -0.02, relativeVelocity: Vector3(0, 0, -2), relativeAngularVelocity: .zero,
            startTimeSeconds: 0, timeStepSeconds: 0.001)
        let evaluator: any ContactLawEvaluating = CompliantContactEvaluator()
        accepted = try evaluator.initialHistory(identity: identity, pair: pair, timeSeconds: input.startTimeSeconds, work: &work)
        direction = try ContactDirection(separation: -0.003, relativeVelocity: Vector3(0, 0, 0.4))
        impactDirection = try ContactImpactDirection(approachSpeed: 0.3, incomingNormalEnergy: -0.5)
    }

    /// Changes only the separation input while keeping the original law, history, frame and interval.
    func contactInput(separation: Double) throws(ContactLawError) -> ContactInput {
        try ContactInput(identity: input.identity, basis: input.basis, separation: separation,
            relativeVelocity: input.relativeVelocity, relativeAngularVelocity: input.relativeAngularVelocity,
            startTimeSeconds: input.startTimeSeconds, timeStepSeconds: input.timeStepSeconds)
    }

    @inline(never)
    static func unsupported(work: inout ContactWork) throws -> ContactDerivativeProbeSource {
        let friction = ContactFrictionLaw.elasticCoulomb(try ContactFrictionParameters(staticFirst: 0.8,
            staticSecond: 0.4, dynamicFirst: 0.4, dynamicSecond: 0.2,
            tangentialStiffness: 2000, transitionSpeed: 0.1))
        return try Self(friction: friction, work: &work)
    }

    private static func material(_ key: String, friction: ContactFrictionLaw) throws -> ContactMaterial {
        try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: key), revision: 1),
            youngModulus: 1e6, poissonsRatio: 0.25, linearStiffness: 2000, normalDamping: 0, huntCrossleyAlpha: 0,
            friction: friction, resistance: ContactResistanceParameters(rollingCoefficient: 0,
                spinningCoefficient: 0, angularRegularization: 0.1), cohesion: .none)
    }
}
