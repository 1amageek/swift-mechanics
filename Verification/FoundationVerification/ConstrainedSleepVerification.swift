import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) static func verifyConstrainedSleepEvolution() throws {
        try constrainedSleepImpactAndReplay()
        try constrainedSleepNoImpactEndpoint()
        try constrainedSleepCancellationRollback()
        print("Constrained sleep evolution passed: directed physical root, retained joint impulse, connected wake, one publication, original cold replay and refusal.")
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepImpactAndReplay() throws {
        let operation = try ConstrainedSleepProbeContext.Operation()
        defer { _ = operation.session.shutdown() }
        let resting = try operation.step()
        try constrainedSleepRestingSource(operation, resting)
        let before = try operation.checkpoint()
        let committed = operation.session.profile().committedTransactions
        let root = try operation.advance(through: 0.4)
        try require(operation.session.profile().committedTransactions == committed + 1)
        try constrainedSleepAcceptedRoot(operation, resting: resting, root: root)
        let rootBytes = try operation.checkpoint()
        try constrainedSleepColdAdmission(operation, root: root)
        try constrainedSleepNoRepeatedEvent(operation, root: root, bytes: rootBytes)
        let later = try operation.step()
        try constrainedSleepOriginalLaterMotion(operation.context, root: root.accepted, later: later.accepted)
        try constrainedSleepHistories(operation, accepted: later.accepted, impactCount: 1)
        let laterBytes = try operation.checkpoint()
        try constrainedSleepFreshReplay(resting: resting, before: before, root: root, rootBytes: rootBytes,
            later: later, laterBytes: laterBytes)
        try constrainedSleepColdForceRefusal(operation, source: later)
        try constrainedSleepAttemptedWritesRollback(operation, source: later)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepRestingSource(_ operation: ConstrainedSleepProbeContext.Operation,
        _ endpoint: ConstrainedSleepProbeContext.AcceptedEndpoint) throws {
        let physical = endpoint.accepted.physical.state, context = operation.context
        try require(abs(physical.time - 0.1) < 1e-12 && endpoint.accepted.checkpoint.acceptedSteps == 1)
        try require(physical.q[context.source.firstIndex] == 0 && physical.q[context.source.secondIndex] == 0)
        try require(abs(physical.q[context.source.sliderIndex] - 0.65) < 1e-12)
        try require(physical.v[context.source.firstIndex] == 0 && physical.v[context.source.secondIndex] == 0)
        try require(physical.v[context.source.sliderIndex] == -1 && physical.acceleration.allSatisfy { $0 == 0 })
        let history = try context.history(operation.sleep, accepted: endpoint.accepted)
        guard let gear = context.program.islands.firstIndex(where: { $0.id == operation.environment.gearIslandID }),
              let striker = context.program.islands.firstIndex(where: { $0.id == operation.environment.strikerIslandID }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        try require(history.asleep[gear] && !history.asleep[striker])
        try require(context.program.islands[gear].sourceCoordinateIndices == [context.source.firstIndex, context.source.secondIndex])
        try constrainedSleepHistories(operation, accepted: endpoint.accepted, impactCount: 0)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepAcceptedRoot(_ operation: ConstrainedSleepProbeContext.Operation,
        resting: ConstrainedSleepProbeContext.AcceptedEndpoint, root: ConstrainedSleepProbeContext.EventEndpoint) throws {
        guard let impulse = root.impact else { throw FoundationVerificationError.analyticCheckFailed }
        try constrainedSleepOriginalImpulse(operation.context, impulse, restitution: 1,
            sourceSequence: resting.accepted.checkpoint.acceptedSteps, accepted: root.accepted)
        try require(root.accepted == operation.session.snapshot())
        try require(root.accepted.checkpoint.random == resting.accepted.checkpoint.random)
        try require(root.work.acceptedSegments == 1 && root.work.acceptedImpacts == 1)
        try require(root.work.queries > 0 && root.work.rootIterations > 0)
        try require(root.work.numerical.operations > 0 && root.work.collision.operations > 0 && root.work.contact.operations > 0)
        try require(root.work.loads.consumed > 0 && root.work.islands.queries > 0)
        try require(root.work.islands.contributorEncoding.operations > 0 && root.work.checkpointAdmission != nil)
        try require(!root.work.failedSupplierWorkUnavailable)
        let sleepHistory = try operation.context.history(operation.sleep, accepted: root.accepted)
        try require(!sleepHistory.asleep.contains(true))
        try require(sleepHistory.wakeSequence == root.accepted.checkpoint.acceptedSteps)
        try require(sleepHistory.lastWakeEventID == 41 && sleepHistory.lastWakeKind == 1)
        try require(sleepHistory.lastWakeTime.bitPattern == root.accepted.physical.state.time.bitPattern)
        for index in operation.context.program.islands.indices {
            try require(sleepHistory.lastWakeIslands[index] == (operation.context.program.islands[index].id == operation.environment.gearIslandID || operation.context.program.islands[index].id == operation.environment.strikerIslandID))
        }
        let history = try operation.eventHistory(root.accepted)
        try require(history.wakeIslandIDs.contains(operation.environment.gearIslandID))
        try require(history.sourceSequence == resting.accepted.checkpoint.acceptedSteps)
        try require(history.targetSequence == root.accepted.checkpoint.acceptedSteps)
        try require(history.lastEventID == 41 && history.lastImpactTime.bitPattern == root.accepted.physical.state.time.bitPattern)
        try constrainedSleepHistories(operation, accepted: root.accepted, impactCount: 1)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepHistories(_ operation: ConstrainedSleepProbeContext.Operation,
        accepted: RuntimeAcceptedState, impactCount: UInt64) throws {
        let sleep = try operation.context.history(operation.sleep, accepted: accepted)
        let event = try operation.eventHistory(accepted)
        guard let record = accepted.checkpoint.contributors.first(where: { $0.id == operation.sleep.continuation.schema.id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let integration = try operation.sleep.continuation.history(record)
        let physical = accepted.physical.state, sequence = accepted.checkpoint.acceptedSteps
        try require(sleep.acceptedSequence == sequence && event.acceptedSequence == sequence && integration.acceptedSteps == sequence)
        try require(sleep.acceptedTime.bitPattern == physical.time.bitPattern && event.acceptedTime.bitPattern == physical.time.bitPattern)
        try require(integration.acceptedTime.bitPattern == physical.time.bitPattern)
        try require(sleep.position == physical.q && sleep.velocity == physical.v)
        try require(event.position == physical.q && event.velocity == physical.v && event.impactCount == impactCount)
        try require(integration.acceptedPoint == physical.q + physical.v)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepColdAdmission(_ operation: ConstrainedSleepProbeContext.Operation,
        root: ConstrainedSleepProbeContext.EventEndpoint) throws {
        let report = try operation.admit(root.accepted.checkpoint)
        try require(report.accepted == root.accepted)
        try require(report.checkpointAdmission.physical.numerical.operations > 0)
        try require(report.checkpointAdmission.physical.loads.consumed > 0)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepFreshReplay(resting: ConstrainedSleepProbeContext.AcceptedEndpoint,
        before: [UInt8], root: ConstrainedSleepProbeContext.EventEndpoint, rootBytes: [UInt8],
        later: ConstrainedSleepProbeContext.AcceptedEndpoint, laterBytes: [UInt8]) throws {
        let fresh = try ConstrainedSleepProbeContext.Operation()
        defer { _ = fresh.session.shutdown() }
        let restored = try fresh.restart(before)
        try require(restored.accepted == resting.accepted)
        let repeated = try fresh.advance(through: 0.4)
        try require(repeated.accepted == root.accepted)
        let repeatedBytes = try fresh.checkpoint()
        try require(repeatedBytes == rootBytes)
        let repeatedLater = try fresh.step()
        try require(repeatedLater.accepted == later.accepted)
        let repeatedLaterBytes = try fresh.checkpoint()
        try require(repeatedLaterBytes == laterBytes)
        try constrainedSleepFreshPostImpact(root: root, rootBytes: rootBytes, later: later, laterBytes: laterBytes)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepFreshPostImpact(root: ConstrainedSleepProbeContext.EventEndpoint,
        rootBytes: [UInt8], later: ConstrainedSleepProbeContext.AcceptedEndpoint, laterBytes: [UInt8]) throws {
        let fresh = try ConstrainedSleepProbeContext.Operation()
        defer { _ = fresh.session.shutdown() }
        let restored = try fresh.restart(rootBytes)
        try require(restored.accepted == root.accepted)
        let repeated = try fresh.step()
        try require(repeated.accepted == later.accepted)
        let bytes = try fresh.checkpoint()
        try require(bytes == laterBytes)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepNoRepeatedEvent(_ operation: ConstrainedSleepProbeContext.Operation,
        root: ConstrainedSleepProbeContext.EventEndpoint, bytes: [UInt8]) throws {
        let unchanged = try operation.advance(through: root.accepted.physical.state.time)
        try require(unchanged.accepted == root.accepted && unchanged.impact == nil)
        try require(unchanged.work.acceptedSegments == 0 && unchanged.work.acceptedImpacts == 0)
        try constrainedSleepPostImpactDomainRefusal(operation, root: root)
        let after = try operation.checkpoint()
        try require(after == bytes)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepPostImpactDomainRefusal(_ operation: ConstrainedSleepProbeContext.Operation,
        root: ConstrainedSleepProbeContext.EventEndpoint) throws {
        let work = try operation.context.evolutionWork()
        let through = root.accepted.physical.state.time + 0.05
        do throws(ConstrainedSleepEvolutionFailure) {
            _ = try operation.evolution.advanceToNextImpact(operation.session, through: through, work: work,
                cancellation: operation.context.cancellation)
        } catch {
            guard case .hybrid(.unsupportedDomain) = error.cause else { throw error }
            try require(error.accepted == root.accepted && error.work.acceptedSegments == 0 && error.work.acceptedImpacts == 0)
            return
        }
        throw FoundationVerificationError.analyticCheckFailed
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepNoImpactEndpoint() throws {
        let operation = try ConstrainedSleepProbeContext.Operation()
        defer { _ = operation.session.shutdown() }
        let resting = try operation.step()
        let result = try operation.advance(through: 0.2)
        try require(result.impact == nil && result.work.acceptedImpacts == 0 && result.work.acceptedSegments == 1)
        try require(result.accepted.checkpoint.acceptedSteps == resting.accepted.checkpoint.acceptedSteps + 1)
        try require(result.accepted.physical.state.time == 0.2)
        try require(abs(result.accepted.physical.state.q[operation.context.source.sliderIndex] - 0.55) < 1e-12)
        try require(result.accepted.physical.state.v[operation.context.source.sliderIndex] == -1)
        try require(result.accepted.checkpoint.random == resting.accepted.checkpoint.random)
        let history = try operation.context.history(operation.sleep, accepted: result.accepted)
        guard let gear = operation.context.program.islands.firstIndex(where: { $0.id == operation.environment.gearIslandID }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        try require(history.asleep[gear])
        try constrainedSleepHistories(operation, accepted: result.accepted, impactCount: 0)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepCancellationRollback() throws {
        let operation = try ConstrainedSleepProbeContext.Operation()
        defer { _ = operation.session.shutdown() }
        let resting = try operation.step()
        let before = try operation.checkpoint()
        let work = try operation.context.evolutionWork()
        operation.context.cancellation.cancel()
        do throws(ConstrainedSleepEvolutionFailure) {
            _ = try operation.evolution.advanceToNextImpact(operation.session, through: 0.4, work: work,
                cancellation: operation.context.cancellation)
        } catch {
            guard case .hybrid(.cancelled) = error.cause else { throw error }
            try require(error.accepted == resting.accepted && error.work.acceptedSegments == 0 && error.work.acceptedImpacts == 0)
            let after = try operation.checkpoint()
            try require(after == before && operation.session.snapshot() == resting.accepted)
            return
        }
        throw FoundationVerificationError.analyticCheckFailed
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepColdForceRefusal(_ operation: ConstrainedSleepProbeContext.Operation,
        source: ConstrainedSleepProbeContext.AcceptedEndpoint) throws {
        let bytes = try operation.checkpoint()
        let forged = try constrainedSleepForgedAccelerationBytes(operation, source: source)
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        let operating: any RuntimeSessionOperating = operation.session
        do throws(RuntimeFailure) {
            _ = try operating.restart(forged, codec: codec)
        } catch {
            guard error.code == .invalidContributor else { throw error }
            try require(operation.session.snapshot() == source.accepted)
            let after = try operation.checkpoint()
            try require(after == bytes)
            return
        }
        throw FoundationVerificationError.analyticCheckFailed
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepForgedAccelerationBytes(_ operation: ConstrainedSleepProbeContext.Operation,
        source: ConstrainedSleepProbeContext.AcceptedEndpoint) throws -> [UInt8] {
        let checkpoint = source.accepted.checkpoint, physical = checkpoint.physical
        var acceleration = physical.acceleration
        acceleration[operation.context.source.firstIndex] += 1
        acceleration[operation.context.source.secondIndex] -= 1
        // This preserves the original gear acceleration row but violates zero-load original force.
        let forged = try KinematicState(revision: physical.revision, time: physical.time,
            q: physical.q, v: physical.v, acceleration: acceleration, prescribedAnchors: physical.prescribedAnchors)
        let input = try RuntimeCheckpoint(model: checkpoint.model, continuation: checkpoint.continuation,
            physical: forged, contributors: checkpoint.contributors, random: checkpoint.random, acceptedSteps: checkpoint.acceptedSteps)
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        return try codec.encode(input, capacity: operation.configuration.capacity)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepAttemptedWritesRollback(_ operation: ConstrainedSleepProbeContext.Operation,
        source: ConstrainedSleepProbeContext.AcceptedEndpoint) throws {
        let bytes = try operation.checkpoint()
        let a = operation.context.source.firstIndex, b = operation.context.source.secondIndex
        let operating: any RuntimeSessionOperating = operation.session
        let failed = operating.profile().failedTransactions
        do throws(RuntimeFailure) {
            _ = try operating.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision in
                try control.beginWorkBlock(units: 1)
                _ = try trial.nextRandom()
                let first = try trial.velocity(at: a), second = try trial.velocity(at: b)
                try trial.setVelocity(first + 1, at: a)
                try trial.setVelocity(second - 1, at: b)
                // No new matching histories are supplied: real contextual Runtime admission must refuse.
                return .accept
            }
        } catch {
            guard error.code == .invalidContributor else { throw error }
            try require(operating.snapshot() == source.accepted)
            try require(operating.profile().failedTransactions == failed + 1)
            let after = try operation.checkpoint()
            try require(after == bytes)
            return
        }
        throw FoundationVerificationError.analyticCheckFailed
    }

    /// Independently checks the genuine whole constrained jump at the physically derived root.
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepOriginalImpulse(
        _ context: ConstrainedSleepProbeContext, _ impulse: ConstrainedNormalImpulseResult,
        restitution: Double, sourceSequence: UInt64, accepted: RuntimeAcceptedState) throws {
        let a = context.source.firstIndex, b = context.source.secondIndex, c = context.source.sliderIndex
        let physical = accepted.physical.state
        let root = (0.75 - 2 * 0.25) / 1.0
        let j = 4 * (1 + restitution) / 3
        try require(abs(physical.time - root) < 1e-9 && abs(impulse.time - root) < 1e-9)
        try require(impulse.eventID == 41 && impulse.velocity.count == 3 && impulse.retainedImpulses.count == 1)
        try require(accepted.checkpoint.acceptedSteps == sourceSequence + 1)
        try require(physical.v == impulse.velocity)
        try require(abs(physical.q[a]) < 1e-9 && abs(physical.q[b]) < 1e-9 && abs(physical.q[c] - 0.5) < 1e-9)
        try require(abs(physical.v[a] + j / 4) < 1e-9)
        try require(abs(physical.v[b] - j / 4) < 1e-9)
        try require(abs(physical.v[c] + 1 - j / 2) < 1e-9)
        try require(abs(physical.v[a] + physical.v[b]) < 1e-9)
        try require(abs(-physical.v[a] + physical.v[c] - restitution) < 1e-9)
        try require(abs(impulse.contactImpulse - j) < 1e-9 && abs(impulse.retainedImpulses[0] - j / 2) < 1e-9)
        let before = impulse.source.source.physical.state
        try require(before.v[a] == 0 && before.v[b] == 0 && before.v[c] == -1)
        try require(before.q == physical.q && before.time == physical.time)
        try require(impulse.source.retainedRows == [1, 1, 0] && impulse.source.impact.normalRows == [-1, 0, 1])
        try require(impulse.source.impact.system.massMatrix == [2, 0, 0, 0, 2, 0, 0, 0, 2])
        let originalContact = [-j, 0, j], originalRetained = [j / 2, j / 2, 0]
        var kinetic = 0.0
        for index in 0..<3 {
            try require(abs(2 * (physical.v[index] - before.v[index]) - originalContact[index] - originalRetained[index]) < 1e-9)
            try require(abs(impulse.retainedGeneralizedImpulse[index] - originalRetained[index]) < 1e-9)
            // I_A=I_B=m_C=2 and each source COM is at its joint origin.
            kinetic += physical.v[index] * physical.v[index]
            try require(abs(physical.acceleration[index]) < 1e-9)
        }
        let loss = 2 * (1 - restitution * restitution) / 3
        try require(abs(1 - kinetic - loss) < 1e-9)
        try require(abs(impulse.kineticEnergyBefore - 1) < 1e-9 && abs(impulse.kineticEnergyAfter - kinetic) < 1e-9)
        try require(abs(impulse.predictedLostEnergy - loss) < 1e-9)
        let witness = impulse.source.impact.contacts[0].witness
        try require(abs(witness.separation) < 1e-9)
        try require(abs(witness.pointA.x - 1) < 1e-9 && abs(witness.pointA.y - 0.25) < 1e-9 && witness.pointA.z == 0)
        try require(abs(witness.pointB.x - 1) < 1e-9 && abs(witness.pointB.y - 0.25) < 1e-9 && witness.pointB.z == 0)
        try require(abs(witness.normal.x) < 1e-9 && abs(witness.normal.y - 1) < 1e-9 && witness.normal.z == 0)
        try require(impulse.normalSpeedBefore < 0 && abs(impulse.normalSpeedAfter - restitution) < 1e-9)
        try require(accepted.checkpoint.physical == physical)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func constrainedSleepOriginalLaterMotion(
        _ context: ConstrainedSleepProbeContext, root: RuntimeAcceptedState, later: RuntimeAcceptedState) throws {
        let a = context.source.firstIndex, b = context.source.secondIndex, c = context.source.sliderIndex
        let original = root.physical.state, physical = later.physical.state
        let dt = physical.time - original.time
        try require(dt > 0 && later.checkpoint.acceptedSteps == root.checkpoint.acceptedSteps + 1)
        try require(abs(physical.q[a] + (2.0 / 3) * dt) < 1e-9)
        try require(abs(physical.q[b] - (2.0 / 3) * dt) < 1e-9)
        try require(abs(physical.q[c] - 0.5 - dt / 3) < 1e-9)
        try require(abs(physical.q[a] + physical.q[b]) < 1e-9)
        for index in 0..<3 {
            try require(abs(physical.v[index] - original.v[index]) < 1e-9)
            try require(abs(physical.acceleration[index]) < 1e-9)
        }
        try require(later.checkpoint.random == root.checkpoint.random)
    }
}
