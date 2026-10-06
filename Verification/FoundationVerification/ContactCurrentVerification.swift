import SwiftMechanics

extension FoundationVerification {
    @inline(never) static func verifyContactCurrentSamples() throws {
        try verifyLoadedCurrentContact()
        try verifyVirginCurrentContact()
        try verifyRotatedCurrentContact()
        try verifyCurrentContactRefusals()
    }

    @inline(never) private static func verifyLoadedCurrentContact() throws {
        let context = try ContactCurrentProbeContext()
        let sampler: any ContactCurrentEvaluating = CompliantContactCurrentEvaluator()
        var work = try ContactCurrentProbeContext.makeWork()
        let input = try context.currentInput(materialVelocity: Vector3(3, -2, -1))
        let result = try sampler.sample(input: input, pair: context.pair, accepted: context.accepted,
            policy: context.policy, work: &work)
        try require(result.acceptedHistory == context.accepted && context.virgin.sequence == 0)
        try require(result.acceptedHistory.sequence == 1 && result.acceptedHistory.timeSeconds == 1)
        try require(abs(result.acceptedHistory.firstBristleDisplacement - 0.001) < 1e-12)
        try require(abs(result.compressiveNormalForce - 10) < 1e-10)
        try require(abs(result.tangentialForceFirst + 1) < 1e-10 && result.tangentialForceSecond == 0)
        try require(abs(result.normalStoredEnergy - 0.05) < 1e-10)
        try require(abs(result.tangentialStoredEnergy - 0.0005) < 1e-10)
        try require(abs(result.relativeMechanicalPower + 13) < 1e-10)
        try require(abs(result.elasticPotentialRatePower - 13) < 1e-10)
        try require(result.normalDissipationPower == 0 && result.resistanceDissipationPower == 0)
        let repeated = try sampler.sample(input: input, pair: context.pair, accepted: context.accepted,
            policy: context.policy, work: &work)
        try require(repeated.acceptedHistory == result.acceptedHistory && repeated.forceOnB == result.forceOnB)
    }

    @inline(never) private static func verifyVirginCurrentContact() throws {
        let context = try ContactCurrentProbeContext(cohesion: .reversibleLinear(tensileLimit: 20, range: 0.01))
        let sampler: any ContactCurrentEvaluating = CompliantContactCurrentEvaluator()
        var work = try ContactCurrentProbeContext.makeWork()
        let moving = try context.currentInput(useVirginHistory: true, materialVelocity: Vector3(20, -30, -2))
        let result = try sampler.sample(input: moving, pair: context.pair, accepted: context.virgin,
            policy: context.policy, work: &work)
        try require(result.acceptedHistory == context.virgin && result.tangentialStoredEnergy == 0)
        try require(result.tangentialForceFirst == 0 && result.tangentialForceSecond == 0)
        try require(abs(result.relativeMechanicalPower + 20) < 1e-10)
        try require(abs(result.cohesivePotentialEnergy + 0.1) < 1e-10)
        let opening = try context.currentInput(useVirginHistory: true, separation: 0.005,
            materialVelocity: Vector3(20, -30, 2))
        let tensile = try sampler.sample(input: opening, pair: context.pair, accepted: context.virgin,
            policy: context.policy, work: &work)
        try require(tensile.compressiveNormalForce == 0 && abs(tensile.cohesiveNormalForce + 10) < 1e-10)
        try require(abs(tensile.cohesivePotentialEnergy + 0.025) < 1e-10)
        try require(abs(tensile.completeCohesiveSeparationWork - 0.1) < 1e-10)
        try require(abs(tensile.relativeMechanicalPower + 20) < 1e-10)
        try require(abs(tensile.elasticPotentialRatePower - 20) < 1e-10)
        try require(tensile.originalRatePowerResidual < 1e-10 && tensile.acceptedHistory == context.virgin)
    }

    @inline(never) private static func verifyRotatedCurrentContact() throws {
        let rotation = try UnitQuaternion(axis: Vector3(1, 2, 3), angle: 0.7)
        let resistance = try ContactResistanceParameters(rollingCoefficient: 0.1,
            spinningCoefficient: 0.2, angularRegularization: 0.1)
        let context = try ContactCurrentProbeContext(rotation: rotation, resistance: resistance)
        let sampler: any ContactCurrentEvaluating = CompliantContactCurrentEvaluator()
        var work = try ContactCurrentProbeContext.makeWork()
        let input = try context.currentInput(materialVelocity: Vector3(3, 4, -2),
            materialAngularVelocity: Vector3(3, 4, 2))
        let result = try sampler.sample(input: input, pair: context.pair, accepted: context.accepted,
            policy: context.policy, work: &work)
        let expectedForce = try rotation.rotating(Vector3(-1, 0, 10))
        let rollingDenominator = Double(25.01).squareRoot()
        let spinDenominator = Double(4.01).squareRoot()
        let expectedCouple = try rotation.rotating(Vector3(-1.5 / rollingDenominator,
            -2 / rollingDenominator, -2 / spinDenominator))
        let loss = 12.5 / rollingDenominator + 4 / spinDenominator
        try require(try result.forceOnB.subtracting(expectedForce).magnitude() < 1e-9)
        try require(try result.coupleOnB.subtracting(expectedCouple).magnitude() < 1e-9)
        try require(abs(result.resistanceDissipationPower - loss) < 1e-9)
        try require(abs(result.relativeMechanicalPower + 23 + loss) < 1e-9)
        try require(abs(result.elasticPotentialRatePower - 23) < 1e-9)
        try require(result.originalPowerResidual < 1e-9 && result.originalRatePowerResidual < 1e-9)
        try require(result.acceptedHistory == context.accepted)
    }

    @inline(never) private static func verifyCurrentContactRefusals() throws {
        let context = try ContactCurrentProbeContext()
        let sampler: any ContactCurrentEvaluating = CompliantContactCurrentEvaluator()
        var work = try ContactCurrentProbeContext.makeWork()
        var unloaded = false
        let opening = try context.currentInput(separation: 0.01)
        do throws(ContactCurrentError) {
            _ = try sampler.sample(input: opening, pair: context.pair,
                accepted: context.accepted, policy: context.policy, work: &work)
        } catch {
            try require(error == .unloadedBristles)
            unloaded = true
        }
        var overCone = false
        let reduced = try context.currentInput(separation: -0.0005)
        do throws(ContactCurrentError) {
            _ = try sampler.sample(input: reduced, pair: context.pair, accepted: context.accepted,
                policy: context.policy, work: &work)
        } catch {
            guard case .inadmissibleAcceptedTraction(let value, let threshold) = error else {
                throw FoundationVerificationError.unexpectedFailure
            }
            try require(value > threshold)
            overCone = true
        }
        var stale = false
        let wrongTime = try ContactCurrentInput(identity: context.identity, basis: context.basis,
            separation: -0.01, relativeVelocity: .zero, relativeAngularVelocity: .zero, timeSeconds: 2)
        do throws(ContactCurrentError) {
            _ = try sampler.sample(input: wrongTime, pair: context.pair, accepted: context.accepted,
                policy: context.policy, work: &work)
        } catch {
            try require(error == .law(.staleHistory))
            stale = true
        }
        try require(unloaded && overCone && stale && context.accepted.sequence == 1)
    }
}
