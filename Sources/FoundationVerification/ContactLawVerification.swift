import MechanicsCore
import MechanicsModel
import MechanicsContactLaws

extension FoundationVerification {
    static func verifyContactLaws() throws {
        let friction = ContactFrictionLaw.elasticCoulomb(try ContactFrictionParameters(staticFirst: 0.8, staticSecond: 0.4,
            dynamicFirst: 0.4, dynamicSecond: 0.2, tangentialStiffness: 2000, transitionSpeed: 0.1))
        let resistance = try ContactResistanceParameters(rollingCoefficient: 0.1, spinningCoefficient: 0.2, angularRegularization: 0.1)
        let first = try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: "contact-material-a"), revision: 1),
            youngModulus: 1e6, poissonsRatio: 0.25, linearStiffness: 2000, normalDamping: 4, huntCrossleyAlpha: 0.5,
            friction: friction, resistance: resistance, cohesion: .reversibleLinear(tensileLimit: 20, range: 0.01))
        let second = try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: "contact-material-b"), revision: 1),
            youngModulus: 1e6, poissonsRatio: 0.25, linearStiffness: 2000, normalDamping: 4, huntCrossleyAlpha: 0.5,
            friction: friction, resistance: resistance, cohesion: .reversibleLinear(tensileLimit: 20, range: 0.01))
        var work = ContactWork(budget: try ContactBudget(operations: 100000, scalarStorage: 1000, records: 1))
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        let linear = try pairing.combine(first: first, second: second, selection: .linear(maximumPenetration: 0.1, maximumNormalSpeed: 10),
            lossPolicy: .compliantDampingOnly, resistanceRadius: 0.5, override: nil, work: &work)
        let identity = try contactIdentity(geometryRevision: 1)
        let basis = try ContactBasis(frame: identity.frame, contactToQuery: .identity)
        let policy = try ContactAcceptancePolicy(absoluteEnergyTolerance: 1e-10, absolutePowerTolerance: 1e-10,
            relativeTolerance: 1e-11, referenceEnergy: 1, referencePower: 1, coneTolerance: 1e-11)
        let evaluator: any ContactLawEvaluating = CompliantContactEvaluator()
        let accepted = try evaluator.initialHistory(identity: identity, pair: linear, timeSeconds: 0, work: &work)
        let input = try ContactInput(identity: identity, basis: basis, separation: -0.01, relativeVelocity: Vector3(1, 0, -3),
            relativeAngularVelocity: Vector3(3, 4, 2), startTimeSeconds: 0, timeStepSeconds: 0.001)
        let response = try evaluator.evaluate(input: input, pair: linear, accepted: accepted, policy: policy, work: &work)
        try require(abs(response.compressiveNormalForce - 16) < 1e-10 && abs(response.normalStoredEnergy - 0.05) < 1e-10)
        try require(abs(response.normalDissipationPower - 18) < 1e-10 && response.normalForceVelocityDerivative == -2)
        try require(response.frictionRegime == .sticking && abs(response.tangentialForceFirst + 1) < 1e-10)
        try require(abs(response.tangentialStoredEnergy - 0.0005) < 1e-10 && abs(response.tangentialDissipationEnergy - 0.0005) < 1e-10)
        try require(abs(response.coupleOnB.z + 3.2 / Double(4.01).squareRoot()) < 1e-10)
        try require(abs(response.relativeMechanicalPower + 49 + response.resistanceDissipationPower) < 1e-9)
        try require(response.cohesivePotentialEnergy == -0.1 && accepted.sequence == 0 && response.trialHistory.sequence == 1)
        let replay = try evaluator.evaluate(input: input, pair: linear, accepted: accepted, policy: policy, work: &work)
        try require(replay.trialHistory == response.trialHistory)
        let opening = try ContactInput(identity: identity, basis: basis, separation: 0.005, relativeVelocity: .zero,
            relativeAngularVelocity: .zero, startTimeSeconds: 0.001, timeStepSeconds: 0.001)
        let released = try evaluator.evaluate(input: opening, pair: linear, accepted: response.trialHistory, policy: policy, work: &work)
        try require(released.frictionRegime == .released && released.tangentialStoredEnergy == 0)
        try require(abs(released.tangentialDissipationEnergy - 0.0005) < 1e-10 && abs(released.cohesiveNormalForce + 10) < 1e-10)
        try require(abs(released.cohesivePotentialEnergy + 0.025) < 1e-10 && released.completeCohesiveSeparationWork == 0.1)
        let slidingInput = try ContactInput(identity: identity, basis: basis, separation: -0.01, relativeVelocity: Vector3(20, 0, 0),
            relativeAngularVelocity: .zero, startTimeSeconds: 0, timeStepSeconds: 0.001)
        let sliding = try evaluator.evaluate(input: slidingInput, pair: linear, accepted: accepted, policy: policy, work: &work)
        let coefficient = 0.4 + 0.4 * 0.1 / 20.1
        try require(sliding.frictionRegime == .sliding && abs(sliding.tangentialForceFirst + 10 * coefficient) < 1e-9)
        try require(abs(sliding.frictionConeUtilization - 1) < 1e-10 && sliding.originalTangentialEnergyResidual < 1e-10)
        let hertz = try pairing.combine(first: first, second: second, selection: .hertz(effectiveRadius: 0.1, maximumPenetration: 0.01, maximumNormalSpeed: 10),
            lossPolicy: .separateImpact(restitution: 0.6, thresholdSpeed: 1), resistanceRadius: 0.5, override: nil, work: &work)
        let hc = try pairing.combine(first: first, second: second, selection: .huntCrossley(effectiveRadius: 0.1, maximumPenetration: 0.01, maximumNormalSpeed: 10),
            lossPolicy: .compliantDampingOnly, resistanceRadius: 0.5, override: nil, work: &work)
        let normalInput = try ContactInput(identity: identity, basis: basis, separation: -0.001, relativeVelocity: Vector3(0, 0, -2),
            relativeAngularVelocity: .zero, startTimeSeconds: 0, timeStepSeconds: 0.001)
        let hertzHistory = try evaluator.initialHistory(identity: identity, pair: hertz, timeSeconds: 0, work: &work)
        let hcHistory = try evaluator.initialHistory(identity: identity, pair: hc, timeSeconds: 0, work: &work)
        let elastic = try evaluator.evaluate(input: normalInput, pair: hertz, accepted: hertzHistory, policy: policy, work: &work)
        let damped = try evaluator.evaluate(input: normalInput, pair: hc, accepted: hcHistory, policy: policy, work: &work)
        let elasticForce = (4.0 / 3) * (1e6 / (2 * (1 - 0.25 * 0.25))) * Double(0.1).squareRoot() * 0.001 * Double(0.001).squareRoot()
        try require(abs(elastic.compressiveNormalForce - elasticForce) < 1e-9 && abs(damped.compressiveNormalForce - 2 * elasticForce) < 1e-9)
        try require(abs(damped.normalDissipationPower - 2 * elasticForce) < 1e-9)
        let predictor: any ContactImpactPredicting = ThresholdRestitutionPredictor()
        let prediction = try predictor.predict(pair: hertz, approachSpeed: 1, incomingNormalEnergy: 4, work: &work)
        try require(prediction.reboundSpeed == 0.6 && abs(prediction.retainedNormalEnergy - 1.44) < 1e-10 && abs(prediction.lostNormalEnergy - 2.56) < 1e-10)
        var lossRejected = false
        do throws(ContactLawError) {
            _ = try pairing.combine(first: first, second: second, selection: .linear(maximumPenetration: 0.1, maximumNormalSpeed: 10),
                lossPolicy: .separateImpact(restitution: 0.6, thresholdSpeed: 1), resistanceRadius: 0.5, override: nil, work: &work)
        } catch {
            try require(error == .incompatibleLossPolicy)
            lossRejected = true
        }
        let staleIdentity = try contactIdentity(geometryRevision: 2)
        let staleInput = try ContactInput(identity: staleIdentity, basis: basis, separation: -0.01, relativeVelocity: .zero,
            relativeAngularVelocity: .zero, startTimeSeconds: 0, timeStepSeconds: 0.001)
        var staleRejected = false
        do throws(ContactLawError) {
            _ = try evaluator.evaluate(input: staleInput, pair: linear, accepted: accepted, policy: policy, work: &work)
        } catch {
            try require(error == .staleHistory)
            staleRejected = true
        }
        try require(lossRejected && staleRejected)
    }

    private static func contactIdentity(geometryRevision: UInt64) throws -> ContactIdentity {
        try ContactIdentity(key: "verified-contact", firstBody: ModelReference(id: EntityID(kind: .body, key: "contact-a"), revision: 1),
            secondBody: ModelReference(id: EntityID(kind: .body, key: "contact-b"), revision: 1),
            frame: ModelReference(id: EntityID(kind: .frame, key: "contact-world"), revision: 1), firstGeometryRevision: geometryRevision,
            secondGeometryRevision: 1, tangentLayoutRevision: 1)
    }
}
