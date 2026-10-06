import SwiftMechanics

extension FoundationVerification {
    @inline(never) static func verifyMaterialToothContacts() throws {
        try verifyMaterialInitial(.linear, rotated: false)
        try verifyMaterialInitial(.dampedLinear, rotated: true)
        try verifyMaterialInitial(.hertz, rotated: false)
        try verifyMaterialInitial(.huntCrossley, rotated: true)
        try verifyMaterialContinuation()
    }

    private static func materialVector(_ supplied: Vector3, _ expected: Vector3) throws {
        try require(abs(supplied.x - expected.x) < 1e-8)
        try require(abs(supplied.y - expected.y) < 1e-8)
        try require(abs(supplied.z - expected.z) < 1e-8)
    }

    private static func materialNormal(_ parameters: ContactNormalLaw, penetration: Double,
        velocity: Double) -> (elastic: Double, force: Double, energy: Double) {
        switch parameters {
        case .linear(let stiffness, let damping, _, _):
            let elastic = stiffness * penetration
            return (elastic, max(elastic - damping * velocity, 0), 0.5 * stiffness * penetration * penetration)
        case .hertz(let stiffness, _, _, _):
            let elastic = stiffness * penetration * penetration.squareRoot()
            return (elastic, elastic, 0.4 * elastic * penetration)
        case .huntCrossley(let stiffness, let alpha, _, _, _):
            let elastic = stiffness * penetration * penetration.squareRoot()
            return (elastic, elastic * max(1 - alpha * velocity, 0), 0.4 * elastic * penetration)
        }
    }

    @inline(never) private static func verifyMaterialInitial(_ normal: MaterialToothContactProbeContext.NormalLaw,
        rotated: Bool) throws {
        let context = try MaterialToothContactProbeContext(normal: normal, rotated: rotated,
            inputInertia: 2, outputInertia: 3)
        let state = context.initial
        try require(state.observations.count == 1 && state.histories.count == 1)
        let observation = state.observations[0], parameters = context.model.contacts[0].law.parameters
        let sign = context.firstContactIsInput ? 1.0 : -1.0
        let rotation = context.worldRotation
        let point = try rotation.rotating(.unitX)
        let outputOrigin = try rotation.rotating(Vector3(2, 0, 0))
        let axisInput = try rotation.rotating(.unitZ), axisOutput = try rotation.rotating(.unitY)
        let expectedNormal = try rotation.rotating(Vector3(0, -sign, 0))
        let tangentFirst = try rotation.rotating(.unitZ)
        let tangentSecond = try expectedNormal.cross(tangentFirst)
        let relative = try rotation.rotating(Vector3(0, -0.4 * sign, -0.2 * sign))
        let angular = try rotation.rotating(Vector3(0, -0.2 * sign, -0.4 * sign))
        let vn = try expectedNormal.dot(relative)
        let law = materialNormal(parameters.normal, penetration: 0.1, velocity: vn)
        let force = try expectedNormal.scaled(by: law.force)
        let w1 = try tangentFirst.dot(angular), w2 = try tangentSecond.dot(angular)
        let wn = try expectedNormal.dot(angular), resistance = parameters.resistance
        let epsilon = resistance.angularRegularization
        let rolling = -resistance.rollingCoefficient * law.force * parameters.resistanceRadius
            / (w1*w1 + w2*w2 + epsilon*epsilon).squareRoot()
        let spinning = -resistance.spinningCoefficient * law.force * parameters.resistanceRadius * wn
            / (wn*wn + epsilon*epsilon).squareRoot()
        let couple = try tangentFirst.scaled(by: rolling*w1)
            .adding(tangentSecond.scaled(by: rolling*w2)).adding(expectedNormal.scaled(by: spinning))
        let firstOrigin: Vector3 = context.firstContactIsInput ? .zero : outputOrigin
        let secondOrigin: Vector3 = context.firstContactIsInput ? outputOrigin : .zero
        let firstTorque = try point.subtracting(firstOrigin).cross(force.scaled(by: -1)).subtracting(couple)
        let secondTorque = try point.subtracting(secondOrigin).cross(force).adding(couple)
        let inputTorque = context.firstContactIsInput ? firstTorque : secondTorque
        let outputTorque = context.firstContactIsInput ? secondTorque : firstTorque
        let inputAcceleration = try (-2 + axisInput.dot(inputTorque)) / 2
        let outputAcceleration = try (-0.25 + axisOutput.dot(outputTorque)) / 3
        let pairPower = try force.dot(relative) + couple.dot(angular)
        let normalLoss = (law.elastic - law.force) * vn
        let resistanceLoss = try -couple.dot(angular)
        guard case .reversibleLinear(let tensile, let range) = parameters.cohesion else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        try materialVector(observation.applicationPoint, point)
        try materialVector(observation.witness.normal, expectedNormal)
        try require(abs(observation.witness.separation + 0.1) < 1e-8)
        try materialVector(observation.relativePointVelocity, relative)
        try materialVector(observation.relativeAngularVelocity, angular)
        try materialVector(observation.forceOnB, force)
        try materialVector(observation.coupleOnB, couple)
        try materialVector(observation.torqueAtFirstBodyOrigin, firstTorque)
        try materialVector(observation.torqueAtSecondBodyOrigin, secondTorque)
        try require(abs(state.physical.acceleration[context.inputCoordinateIndex] - inputAcceleration) < 1e-8)
        try require(abs(state.physical.acceleration[context.outputCoordinateIndex] - outputAcceleration) < 1e-8)
        try require(abs(state.energy.kineticEnergy - (0.5*2*0.4*0.4 + 0.5*3*0.2*0.2)) < 1e-8)
        try require(abs(state.energy.kineticEnergyRate - (2*0.4*inputAcceleration - 3*0.2*outputAcceleration)) < 1e-8)
        try require(abs(state.energy.kineticEnergyRate - (pairPower - 2*0.4 + 0.25*0.2)) < 1e-8)
        try require(abs(state.normalStoredEnergy - law.energy) < 1e-8)
        try require(state.tangentialStoredEnergy == 0)
        try require(abs(state.cohesivePotentialEnergy + tensile*range/2) < 1e-8)
        try require(abs(state.normalDissipationPower - normalLoss) < 1e-8)
        try require(abs(state.resistanceDissipationPower - resistanceLoss) < 1e-8 && resistanceLoss > 0)
        try require(abs(observation.relativeMechanicalPower - pairPower) < 1e-8)
        try require(state.accumulatedDissipation == 0 && state.accumulatedDriveWork == 0)
        guard case .current(let current) = observation.evidence else { throw FoundationVerificationError.analyticCheckFailed }
        try require(current.acceptedHistory == state.histories[0] && current.acceptedHistory.sequence == 0)
        try require(current.acceptedHistory.timeSeconds == 0 && current.acceptedHistory.firstBristleDisplacement == 0)
        var work = try context.makeWork()
        let endpoint = try context.step(accepted: state, timeStep: 0.0001, work: &work)
        try verifyMaterialEndpoint(context, prior: state, endpoint: endpoint, step: 0.0001)
    }

    @inline(never) private static func verifyMaterialEndpoint(_ context: MaterialToothContactProbeContext,
        prior: MaterialToothContactState, endpoint: MaterialToothContactState, step: Double) throws {
        try require(endpoint.histories.count == 1 && endpoint.observations.count == 1)
        let observation = endpoint.observations[0]
        guard case .trial(let trial) = observation.evidence else { throw FoundationVerificationError.analyticCheckFailed }
        try require(endpoint.histories[0] == trial.trialHistory)
        try require(endpoint.histories[0].sequence == prior.histories[0].sequence + 1)
        try require(endpoint.histories[0].timeSeconds == endpoint.physical.time)
        try require(trial.acceptedHistorySequence == prior.histories[0].sequence)
        let normalLoss = 0.5*step*(prior.normalDissipationPower + endpoint.normalDissipationPower)
        let resistanceLoss = 0.5*step*(prior.resistanceDissipationPower + endpoint.resistanceDissipationPower)
        try require(abs(endpoint.accumulatedNormalDissipation - prior.accumulatedNormalDissipation - normalLoss) < 1e-8)
        try require(abs(endpoint.accumulatedResistanceDissipation - prior.accumulatedResistanceDissipation - resistanceLoss) < 1e-8)
        try require(abs(endpoint.accumulatedTangentialDissipation - prior.accumulatedTangentialDissipation
            - trial.tangentialDissipationEnergy) < 1e-8)
        try require(endpoint.tangentialStoredEnergy > 0 && trial.tangentialDissipationEnergy > 0)
        let drive = context.model.driveForce[0]*(endpoint.physical.q[0] - prior.physical.q[0])
            + context.model.driveForce[1]*(endpoint.physical.q[1] - prior.physical.q[1])
        try require(abs(endpoint.accumulatedDriveWork - prior.accumulatedDriveWork - drive) < 1e-8)
        let defect = endpoint.energy.kineticEnergy + endpoint.contactStoredEnergy - endpoint.initialTotalEnergy
            - endpoint.accumulatedDriveWork + endpoint.accumulatedDissipation
        try require(abs(endpoint.originalEnergyDefect - defect) < 1e-8)
        let power = try observation.forceOnB.dot(observation.relativePointVelocity)
            + observation.coupleOnB.dot(observation.relativeAngularVelocity)
        try require(abs(observation.relativeMechanicalPower - power) < 1e-8)
        try require(prior.histories[0].timeSeconds == prior.physical.time)
    }

    @inline(never) private static func materialEnd(_ context: MaterialToothContactProbeContext,
        step: Double) throws -> MaterialToothContactState {
        var work = try context.makeWork()
        return try context.advance(accepted: context.initial, to: 0.01, timeStep: step, work: &work).accepted
    }

    @inline(never) private static func verifyMaterialContinuation() throws {
        let context = try MaterialToothContactProbeContext(normal: .huntCrossley)
        let coarse = try materialEnd(context, step: 0.001)
        let fine = try materialEnd(context, step: 0.0005)
        let finer = try materialEnd(context, step: 0.00025)
        var coarseDifference = 0.0, fineDifference = 0.0
        for i in 0..<2 {
            coarseDifference += abs(coarse.physical.q[i] - fine.physical.q[i]) + abs(coarse.physical.v[i] - fine.physical.v[i])
            fineDifference += abs(fine.physical.q[i] - finer.physical.q[i]) + abs(fine.physical.v[i] - finer.physical.v[i])
        }
        try require(fineDifference < coarseDifference)
        try require(abs(finer.originalEnergyDefect) < abs(coarse.originalEnergyDefect))
        let fresh = try MaterialToothContactProbeContext(normal: .huntCrossley)
        var work = try fresh.makeWork()
        let replay = try fresh.advance(accepted: context.initial, to: 0.01, timeStep: 0.00025, work: &work).accepted
        try require(replay.physical == finer.physical && replay.histories == finer.histories)
        try require(replay.accumulatedDriveWork == finer.accumulatedDriveWork)
        try require(replay.accumulatedDissipation == finer.accumulatedDissipation)
        let changed = try MaterialToothContactProbeContext(normal: .huntCrossley, inputInertia: 2)
        work = try changed.makeWork()
        var refused = false
        do throws(ToothContactError) { _ = try changed.step(accepted: context.initial, timeStep: 0.001, work: &work) }
        catch {
            guard case .staleSource = error else { throw FoundationVerificationError.unexpectedFailure }
            refused = true
        }
        try require(refused && context.initial.histories[0].sequence == 0)
        work = try context.makeWork()
        refused = false
        do throws(ToothContactError) {
            _ = try ReferenceToothContactEvolution(model: context.model).initial(time: 0, q: [0, 0], v: [0, 0],
                evaluationTimeStep: 0.001, policy: context.policy, work: &work)
        } catch {
            guard case .unsupportedDomain = error else { throw FoundationVerificationError.unexpectedFailure }
            refused = true
        }
        try require(refused && work.supplierCalls == 0)
    }
}
