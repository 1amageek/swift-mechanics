import MechanicsCore
import MechanicsModel
import MechanicsContactLaws

extension FoundationVerification {
    @inline(never)
    static func verifyMaterialSites() throws {
        let body = ModelReference(id: try EntityID(kind: .body, key: "self-body"), revision: 1)
        let frame = ModelReference(id: try EntityID(kind: .frame, key: "self-world"), revision: 1)
        let identity = try materialSiteIdentity(body: body, frame: frame, siteRevision: 1)
        var work = ContactWork(budget: try ContactBudget(operations: 100000, scalarStorage: 1000, records: 1))
        let friction = ContactFrictionLaw.elasticCoulomb(try ContactFrictionParameters(staticFirst: 0.8,
            staticSecond: 0.8, dynamicFirst: 0.4, dynamicSecond: 0.4,
            tangentialStiffness: 2000, transitionSpeed: 0.1))
        let material = try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: "self-material"), revision: 1),
            youngModulus: 1e6, poissonsRatio: 0.25, linearStiffness: 2000, normalDamping: 0,
            huntCrossleyAlpha: 0, friction: friction,
            resistance: ContactResistanceParameters(rollingCoefficient: 0, spinningCoefficient: 0, angularRegularization: 0.1), cohesion: .none)
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        let pair = try pairing.combine(first: material, second: material,
            selection: .linear(maximumPenetration: 0.2, maximumNormalSpeed: 100),
            lossPolicy: .compliantDampingOnly, resistanceRadius: 0.5, override: nil, work: &work)
        let evaluator: any ContactLawEvaluating = CompliantContactEvaluator()
        let accepted = try evaluator.initialHistory(identity: identity, pair: pair, timeSeconds: 0, work: &work)
        let input = try ContactInput(identity: identity, basis: ContactBasis(frame: frame, contactToQuery: .identity),
            separation: -0.01, relativeVelocity: Vector3(1, 0, 0), relativeAngularVelocity: .zero,
            startTimeSeconds: 0, timeStepSeconds: 0.001)
        let policy = try ContactAcceptancePolicy(absoluteEnergyTolerance: 1e-10, absolutePowerTolerance: 1e-10,
            relativeTolerance: 1e-11, referenceEnergy: 1, referencePower: 1, coneTolerance: 1e-11)
        let response = try evaluator.evaluate(input: input, pair: pair, accepted: accepted, policy: policy, work: &work)
        try require(identity.firstBody == identity.secondBody && response.frictionRegime == .sticking)
        try require(abs(response.compressiveNormalForce - 10) < 1e-10 && abs(response.tangentialForceFirst + 1) < 1e-10)
        try require(abs(response.tangentialStoredEnergy - 0.0005) < 1e-10 && abs(response.tangentialDissipationEnergy - 0.0005) < 1e-10)
        try require(abs(response.relativeMechanicalPower + 1) < 1e-10 && accepted.sequence == 0)
        let replay = try evaluator.evaluate(input: input, pair: pair, accepted: accepted, policy: policy, work: &work)
        try require(replay.trialHistory == response.trialHistory)
        let changed = try materialSiteIdentity(body: body, frame: frame, siteRevision: 2)
        let stale = try ContactInput(identity: changed, basis: input.basis, separation: input.separation,
            relativeVelocity: input.relativeVelocity, relativeAngularVelocity: .zero, startTimeSeconds: 0, timeStepSeconds: 0.001)
        var rejected = false
        do throws(ContactLawError) {
            _ = try evaluator.evaluate(input: stale, pair: pair, accepted: accepted, policy: policy, work: &work)
        } catch {
            try require(error == .staleHistory)
            rejected = true
        }
        try require(rejected && accepted.identity == identity && accepted.sequence == 0)
    }

    private static func materialSiteIdentity(body: ModelReference, frame: ModelReference,
                                             siteRevision: UInt64) throws -> ContactIdentity {
        try ContactIdentity(key: "self-pair", firstBody: body, secondBody: body, frame: frame,
            firstGeometryRevision: 1, secondGeometryRevision: 1, tangentLayoutRevision: 1,
            firstMaterialSite: ContactMaterialSite(key: "vertex-4", revision: siteRevision),
            secondMaterialSite: ContactMaterialSite(key: "face-12", revision: 1))
    }
}
