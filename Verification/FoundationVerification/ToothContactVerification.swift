import SwiftMechanics

extension FoundationVerification {
    @inline(never) static func verifyToothContactEvolution() throws {
        let context = try ToothContactProbeContext()
        let initial = try context.initial()
        try require(initial.physical.q == [0, 0] && initial.physical.v == [0, 0])
        for index in 0..<2 {
            try require(abs(initial.physical.acceleration[index] - context.expectedInitialAcceleration[index]) < 1e-8)
        }
        try verifyNominalToothState(context, state: initial)
        var work = try context.makeWork()
        let next = try context.makeService().step(accepted: initial, timeStep: 0.001,
                                                 policy: context.policy, work: &work)
        try require(next.physical.v[context.inputCoordinateIndex] < 0 &&
                    next.physical.v[context.outputCoordinateIndex] > 0)
        try require(next.acceptedSteps == initial.acceptedSteps + 1 && next.histories.count == 1)
        try require(next.histories[0].sequence == initial.histories[0].sequence + 1)
        try require(next.histories[0].timeSeconds == next.physical.time)
        try require(work.operations > 0 && work.supplierCalls > 0)
        try verifyNominalToothState(context, state: next)
        try verifyToothRefusalAndReplay(context, initial: initial, next: next)
        try verifyToothTimeRefinement(context, initial: initial)
        print("Tooth contact passed: original contact torque drives the loaded output, with physical residuals, histories and fresh-owner replay.")
    }

    @inline(never) private static func verifyNominalToothState(_ context: ToothContactProbeContext,
                                                              state: ToothContactState) throws {
        let oracle = try context.nominal(q: state.physical.q, v: state.physical.v)
        try require(state.observations.count == 1 && state.histories.count == 1)
        let contact = state.observations[0]
        try require(abs(contact.witness.separation - oracle.separation) < 1e-9)
        try require(abs(contact.witness.approximationError - context.expectedPairApproximationError) < 1e-12)
        try require(abs(state.contactStoredEnergy - oracle.storedEnergy) < 1e-9)
        try require(abs(state.energy.kineticEnergy - oracle.kineticEnergy) < 1e-9)
        try require(abs(state.energy.kineticEnergyRate - oracle.contactPower - oracle.drivePower) < 1e-8)
        try require(abs(state.accumulatedDriveWork - oracle.accumulatedDriveWork) < 1e-9)
        for index in 0..<2 {
            try require(abs(state.generalizedContactForce[index] - oracle.generalizedContactForce[index]) < 1e-8)
            try require(abs(state.physical.acceleration[index] - oracle.acceleration[index]) < 1e-8)
        }
        let inputPoint = context.firstContactIsInput ? contact.witness.pointA : contact.witness.pointB
        let outputPoint = context.firstContactIsInput ? contact.witness.pointB : contact.witness.pointA
        let inputForce = context.firstContactIsInput ? contact.forceOnA : contact.forceOnB
        let outputForce = context.firstContactIsInput ? contact.forceOnB : contact.forceOnA
        let inputTorque = context.firstContactIsInput ? contact.torqueAtFirstBodyOrigin : contact.torqueAtSecondBodyOrigin
        let outputTorque = context.firstContactIsInput ? contact.torqueAtSecondBodyOrigin : contact.torqueAtFirstBodyOrigin
        try requireVectorNear(inputPoint, oracle.inputPoint)
        try requireVectorNear(outputPoint, oracle.outputPoint)
        try requireVectorNear(inputForce, oracle.forceOnInput)
        try requireVectorNear(outputForce, oracle.forceOnOutput)
        try requireVectorNear(inputTorque, oracle.inputTorque)
        try requireVectorNear(outputTorque, oracle.outputTorque)
        let sign = context.firstContactIsInput ? 1.0 : -1.0
        try require(abs(contact.witness.normal.x - sign * oracle.normalInputToOutput.x) < 1e-9 &&
                    abs(contact.witness.normal.y - sign * oracle.normalInputToOutput.y) < 1e-9)
        try require(abs(contact.relativePointVelocity.x - sign * oracle.relativePointVelocity.x) < 1e-9 &&
                    abs(contact.relativePointVelocity.y - sign * oracle.relativePointVelocity.y) < 1e-9)
        try require(abs(contact.slipVelocity.x - sign * oracle.slipVelocity.x) < 1e-9 &&
                    abs(contact.slipVelocity.y - sign * oracle.slipVelocity.y) < 1e-9)
    }

    @inline(never) private static func requireVectorNear(_ actual: Vector3, _ expected: Vector3) throws {
        try require(abs(actual.x - expected.x) < 1e-9 && abs(actual.y - expected.y) < 1e-9 &&
                    abs(actual.z - expected.z) < 1e-9)
    }

    @inline(never) private static func verifyToothRefusalAndReplay(_ context: ToothContactProbeContext,
                                                                 initial: ToothContactState,
                                                                 next: ToothContactState) throws {
        var cancelledWork = try context.makeWork(), refused = false
        let cancelled = try ToothContactProbeContext.makePolicy(isCancelled: { true })
        do throws(ToothContactError) {
            _ = try context.makeService().step(accepted: initial, timeStep: 0.001,
                                               policy: cancelled, work: &cancelledWork)
        } catch { if case .cancelled = error { refused = true } }
        try require(refused && initial.physical.q == [0, 0] && initial.physical.v == [0, 0])
        try require(initial.histories[0].timeSeconds == 0 && initial.acceptedSteps == 0)
        try verifyToothChangedSource(initial)
        let fresh = try ToothContactProbeContext()
        var freshWork = try fresh.makeWork()
        let replay = try fresh.makeService().step(accepted: initial, timeStep: 0.001,
                                                policy: fresh.policy, work: &freshWork)
        try require(replay.physical == next.physical && replay.histories == next.histories)
        try require(replay.generalizedContactForce == next.generalizedContactForce &&
                    replay.accumulatedDriveWork == next.accumulatedDriveWork)
    }

    @inline(never) private static func verifyToothChangedSource(_ accepted: ToothContactState) throws {
        let changed = try ToothContactProbeContext(sourceRevision: 2)
        var work = try changed.makeWork(), refused = false
        do throws(ToothContactError) {
            _ = try changed.makeService().step(accepted: accepted, timeStep: 0.001,
                                               policy: changed.policy, work: &work)
        } catch { if case .staleSource = error { refused = true } }
        try require(refused && accepted.physical.q == [0, 0] && accepted.histories[0].timeSeconds == 0)
    }

    @inline(never) private static func verifyToothTimeRefinement(_ context: ToothContactProbeContext,
                                                              initial: ToothContactState) throws {
        let coarse = try evolvedToothState(context, initial: initial, step: 0.001)
        let fine = try evolvedToothState(context, initial: initial, step: 0.0005)
        let reference = try evolvedToothState(context, initial: initial, step: 0.00025)
        var coarseError = 0.0, fineError = 0.0
        for index in 0..<2 {
            coarseError = max(coarseError, abs(coarse.physical.q[index] - reference.physical.q[index]))
            fineError = max(fineError, abs(fine.physical.q[index] - reference.physical.q[index]))
        }
        try require(coarseError > 0 && fineError < 0.5 * coarseError)
        try require(abs(fine.originalEnergyDefect) < abs(coarse.originalEnergyDefect))
        try verifyNominalToothState(context, state: fine)
    }

    @inline(never) private static func evolvedToothState(_ context: ToothContactProbeContext,
                                                       initial: ToothContactState, step: Double) throws -> ToothContactState {
        var work = try context.makeWork()
        let result = try context.makeService().advance(accepted: initial, to: 0.01,
            timeStep: step, policy: context.policy, work: &work)
        try require(result.accepted.physical.time == 0.01 && result.completedSteps > 0)
        return result.accepted
    }
}
