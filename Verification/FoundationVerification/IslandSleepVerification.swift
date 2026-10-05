import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension FoundationVerification {
    @inline(never) static func verifyIslandSleep() throws {
        let context = try IslandSleepProbeContext(), session = try context.session()
        defer { _ = session.shutdown() }
        let random = session.snapshot().checkpoint.random
        try require(context.original.constructionWork.compilationCalls == 2
            && context.initialConstructionWork.compilationCalls == 0
            && context.initialConstructionWork.numerical.operations > 0
            && context.initialConstructionWork.loads.consumed > 0)
        try verifyIslandSleepPhysical(context, session.snapshot().checkpoint.physical)
        try enterPublicIslandSleep(context, session: session)
        try verifyPublicIslandOmission(context, session: session)
        let saved = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        try verifyPublicIslandQuery(context, session: session)
        try verifyPublicIslandColdReplay(context, session: session, saved: saved)
        try verifyPublicIslandChangedSource(saved: saved)
        try verifyPublicIslandSequenceRefusal(context, session: session)
        try require(session.snapshot().checkpoint.random == random)
    }

    private static func islandSleepNear(_ actual: Double, _ expected: Double) throws {
        try require(actual.isFinite && abs(actual - expected) <= 1e-9 + 1e-10 * abs(expected))
    }

    /// Independent integration of the original mass-two slider under its constant force four.
    @inline(never)
    private static func verifyIslandSleepPhysical(_ context: IslandSleepProbeContext,
                                                _ physical: KinematicState) throws {
        let source = context.original.source
        let dt = physical.time - context.initialPhysical.time
        try require(physical.revision == source.model.stamp.revision && physical.q.count == 3
            && physical.v.count == 3 && physical.acceleration.count == 3 && physical.prescribedAnchors.isEmpty)
        for index in [source.firstIndex, source.secondIndex] {
            try require(physical.q[index] == 0 && physical.v[index] == 0 && physical.acceleration[index] == 0)
        }
        try islandSleepNear(physical.q[source.sliderIndex], 0.5 - dt + dt*dt)
        try islandSleepNear(physical.v[source.sliderIndex], -1 + 2*dt)
        try islandSleepNear(physical.acceleration[source.sliderIndex], 2)
        try islandSleepNear(physical.q[source.firstIndex] + physical.q[source.secondIndex], 0)
        try islandSleepNear(physical.v[source.firstIndex] + physical.v[source.secondIndex], 0)
    }

    @inline(never)
    private static func verifyIslandSleepAssociation(_ context: IslandSleepProbeContext,
        _ accepted: RuntimeAcceptedState, sleeping: Bool) throws {
        let checkpoint = accepted.checkpoint, history = try context.history(accepted)
        try require(checkpoint.model == context.original.source.model.stamp)
        try require(history.acceptedTime.bitPattern == checkpoint.physical.time.bitPattern)
        try require(history.acceptedSequence == checkpoint.acceptedSteps)
        try require(history.position == checkpoint.physical.q && history.velocity == checkpoint.physical.v)
        try require(history.islandIDs == context.original.program.islands.map { $0.id })
        try require(history.asleep.count == 2 && history.restSince.count == 2 && history.lastWakeIslands.count == 2)
        guard let gear = history.islandIDs.firstIndex(of: context.gearID),
              let slider = history.islandIDs.firstIndex(of: context.sliderID) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        try require(history.asleep[gear] == sleeping && !history.asleep[slider])
        if sleeping { try require(history.restSince[gear].isFinite && checkpoint.physical.time - history.restSince[gear] >= 0.15) }
        try require(history.wakeSequence == 0 && history.lastWakeKind == 0 && history.lastWakeEventID == 0
            && !history.lastWakeIslands.contains(true))
        let integration = try context.integrationHistory(accepted)
        try require(integration.acceptedTime.bitPattern == checkpoint.physical.time.bitPattern
            && integration.acceptedSteps == checkpoint.acceptedSteps)
        try require(integration.acceptedPoint == checkpoint.physical.q + checkpoint.physical.v)
        try require(integration.normalizedError == nil && integration.nextStep > 0 && integration.nextStep <= 0.1)
        try require(checkpoint.contributors.count == context.configuration.requiredContributors.count)
        try require(checkpoint.contributors.map { $0.id }.sorted() == context.configuration.requiredContributors.map { $0.id }.sorted())
        try verifyIslandSleepPhysical(context, checkpoint.physical)
    }

    @inline(never)
    private static func enterPublicIslandSleep(_ context: IslandSleepProbeContext,
        session: IslandSleepProbeContext.Session) throws {
        let original = session.snapshot()
        for step in 1...4 {
            var work = context.makeWork()
            let prior = session.snapshot(), result = try context.step(session, work: &work)
            try require(result.integration.accepted == session.snapshot() && result.integration.reachedRequestedTime)
            try require(result.integration.acceptedSteps == 1 && result.integration.rejectedTrials == 0)
            try require(result.integration.accepted.checkpoint.acceptedSteps == prior.checkpoint.acceptedSteps + 1)
            try islandSleepNear(result.integration.accepted.checkpoint.physical.time, original.checkpoint.physical.time + Double(step)*0.1)
            try require(result.integration.accepted.checkpoint.random == original.checkpoint.random)
            try verifyIslandSleepPhysical(context, result.integration.accepted.checkpoint.physical)
            try verifyIslandSleepAdvanceReceipt(result, caller: work)
            try verifyIslandSleepWork(context, work: work)
            if step == 1 { try verifyIslandSleepAssociation(context, result.integration.accepted, sleeping: false) }
        }
        try verifyIslandSleepAssociation(context, session.snapshot(), sleeping: true)
    }

    @inline(never)
    private static func verifyPublicIslandOmission(_ context: IslandSleepProbeContext,
        session: IslandSleepProbeContext.Session) throws {
        context.observed.reset()
        var work = context.makeWork()
        let prior = session.snapshot(), result = try context.step(session, work: &work)
        let calls = context.observed.snapshot()
        try require(calls.gearMotion == 0 && calls.sliderMotion > 0 && calls.association > 0)
        try require(result.integration.work.derivativeCalls >= 4 && result.integration.work.supplierArithmeticCharged > 0)
        try require(!result.integration.work.failedSupplierWorkUnavailable)
        try require(result.integration.accepted.checkpoint.acceptedSteps == prior.checkpoint.acceptedSteps + 1
            && result.integration.accepted.checkpoint.random == prior.checkpoint.random)
        try verifyIslandSleepAssociation(context, result.integration.accepted, sleeping: true)
        try verifyIslandSleepAdvanceReceipt(result, caller: work)
        try verifyIslandSleepWork(context, work: work)
        try verifyPublicIslandAwakeReference(result.integration.accepted.checkpoint.physical,
            omittedArithmetic: result.integration.work.supplierArithmeticCharged)
    }

    @inline(never)
    private static func verifyPublicIslandAwakeReference(_ expected: KinematicState, omittedArithmetic: Int) throws {
        let context = try IslandSleepProbeContext(minimumRestDuration: 10), session = try context.session()
        defer { _ = session.shutdown() }
        for _ in 0..<4 { var work = context.makeWork(); _ = try context.step(session, work: &work) }
        context.observed.reset()
        var work = context.makeWork()
        let result = try context.step(session, work: &work), calls = context.observed.snapshot()
        try require(calls.gearMotion > 0 && calls.sliderMotion > 0)
        try require(!context.history(result.integration.accepted).asleep.contains(true))
        try require(result.integration.accepted.checkpoint.physical == expected)
        try require(result.integration.work.supplierArithmeticCharged > omittedArithmetic)
        try verifyIslandSleepPhysical(context, expected)
        try verifyIslandSleepAdvanceReceipt(result, caller: work)
        try verifyIslandSleepWork(context, work: work)
    }

    @inline(never)
    private static func verifyPublicIslandQuery(_ context: IslandSleepProbeContext,
        session: IslandSleepProbeContext.Session) throws {
        let source = session.snapshot(), before = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        var work = context.makeWork()
        let endpoint = try context.query(source, to: source.checkpoint.physical.time + 0.23, work: &work)
        try require(endpoint.source == source.checkpoint && endpoint.privateAcceptedSteps > 0)
        try require(endpoint.accepted.checkpoint.random == source.checkpoint.random)
        try require(session.snapshot() == source && session.snapshot().checkpoint.acceptedSteps == source.checkpoint.acceptedSteps)
        try require(try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) == before)
        try islandSleepNear(endpoint.physical.time, source.checkpoint.physical.time + 0.23)
        try verifyIslandSleepAssociation(context, endpoint.accepted, sleeping: true)
        try require(work.queries == 1)
        try verifyIslandSleepWork(context, work: work)
        try verifyPublicIslandSmooth(context, source: source, endpoint: endpoint)
        try require(session.snapshot() == source && session.snapshot().checkpoint.random == source.checkpoint.random)
        try require(try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) == before)
    }

    @inline(never)
    private static func verifyPublicIslandSmooth(_ context: IslandSleepProbeContext,
        source: RuntimeAcceptedState, endpoint: IslandSleepTrajectoryEndpoint) throws {
        var work = context.makeWork()
        let candidate = try context.smooth(source, endpoint: endpoint, work: &work)
        try require(candidate.source == source.checkpoint && candidate.physical == endpoint.physical)
        try verifyIslandSmoothPhysicalBits(candidate.source.physical, source.checkpoint.physical)
        try verifyIslandSmoothPhysicalBits(candidate.physical, endpoint.physical)
        let provider: any IslandMechanismSleepContinuing = context.sleep
        let queried = try context.history(endpoint.accepted), history = try provider.history(candidate.sleep)
        let actualIntegration = try provider.continuation.history(candidate.integration)
        let queriedIntegration = try context.integrationHistory(endpoint.accepted)
        let sequence = source.checkpoint.acceptedSteps + 1
        try require(history.acceptedSequence == sequence && actualIntegration.acceptedSteps == sequence
            && sequence != endpoint.accepted.checkpoint.acceptedSteps)
        try require(history.acceptedTime.bitPattern == queried.acceptedTime.bitPattern
            && history.islandIDs == queried.islandIDs && history.asleep == queried.asleep)
        try require(history.position.count == queried.position.count && history.velocity.count == queried.velocity.count
            && history.restSince.count == queried.restSince.count)
        for i in history.position.indices { try require(history.position[i].bitPattern == queried.position[i].bitPattern) }
        for i in history.velocity.indices { try require(history.velocity[i].bitPattern == queried.velocity[i].bitPattern) }
        for i in history.restSince.indices { try require(history.restSince[i].bitPattern == queried.restSince[i].bitPattern) }
        try require(history.wakeSequence == queried.wakeSequence && history.lastWakeTime.bitPattern == queried.lastWakeTime.bitPattern
            && history.lastWakeEventID == queried.lastWakeEventID && history.lastWakeKind == queried.lastWakeKind
            && history.lastWakeIslands == queried.lastWakeIslands)
        try require(actualIntegration.acceptedTime.bitPattern == queriedIntegration.acceptedTime.bitPattern
            && actualIntegration.nextStep.bitPattern == queriedIntegration.nextStep.bitPattern
            && actualIntegration.normalizedError == queriedIntegration.normalizedError
            && actualIntegration.acceptedPoint.count == queriedIntegration.acceptedPoint.count)
        for i in actualIntegration.acceptedPoint.indices {
            try require(actualIntegration.acceptedPoint[i].bitPattern == queriedIntegration.acceptedPoint[i].bitPattern)
        }
        try verifyIslandSleepPhysical(context, candidate.physical)
        try require(work.contributorEncoding.operations > 0)
        try verifyIslandSleepWork(context, work: work)
    }

    private static func verifyIslandSmoothPhysicalBits(_ actual: KinematicState, _ expected: KinematicState) throws {
        try require(actual == expected && actual.time.bitPattern == expected.time.bitPattern)
        for i in actual.q.indices { try require(actual.q[i].bitPattern == expected.q[i].bitPattern) }
        for i in actual.v.indices { try require(actual.v[i].bitPattern == expected.v[i].bitPattern) }
        for i in actual.acceleration.indices { try require(actual.acceleration[i].bitPattern == expected.acceleration[i].bitPattern) }
    }

    @inline(never)
    private static func verifyPublicIslandColdReplay(_ context: IslandSleepProbeContext,
        session: IslandSleepProbeContext.Session, saved: [UInt8]) throws {
        let cold = try IslandSleepProbeContext()
        let decoded = try NativeRuntimeCheckpointCodec().decode(saved, capacity: cold.configuration.capacity)
        cold.observed.reset()
        let admitted = try cold.admit(decoded), calls = cold.observed.snapshot()
        try require(admitted.accepted.checkpoint == decoded && calls.rest > 0 && calls.sliderMotion > 0)
        try require(admitted.checkpointAdmission.physical.numerical.operations > 0
            && admitted.checkpointAdmission.physical.loads.consumed > 0)
        try verifyIslandSleepWork(cold, work: admitted.checkpointAdmission)
        try verifyIslandSleepAssociation(cold, admitted.accepted, sleeping: true)
        try verifyPublicIslandFreshReplay(context, session: session, fresh: cold, saved: saved)
    }

    @inline(never)
    private static func verifyPublicIslandFreshReplay(_ context: IslandSleepProbeContext,
        session: IslandSleepProbeContext.Session, fresh: IslandSleepProbeContext, saved: [UInt8]) throws {
        let restored = try fresh.session()
        defer { _ = restored.shutdown() }
        _ = try restored.restart(saved, codec: NativeRuntimeCheckpointCodec())
        try require(try restored.checkpoint(codec: NativeRuntimeCheckpointCodec()) == saved)
        var originalWork = context.makeWork(), freshWork = fresh.makeWork()
        let originalResult = try context.step(session, work: &originalWork)
        let freshResult = try fresh.step(restored, work: &freshWork)
        try require(originalResult.integration.accepted == freshResult.integration.accepted)
        try verifyIslandSleepAdvanceReceipt(originalResult, caller: originalWork)
        try verifyIslandSleepAdvanceReceipt(freshResult, caller: freshWork)
        try require(try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) == restored.checkpoint(codec: NativeRuntimeCheckpointCodec()))
        try verifyIslandSleepAssociation(context, originalResult.integration.accepted, sleeping: true)
        try verifyIslandSleepAssociation(fresh, freshResult.integration.accepted, sleeping: true)
    }

    @inline(never)
    private static func verifyPublicIslandChangedSource(saved: [UInt8]) throws {
        let source = try IslandDynamicsProbeModel(firstRotationalInertia: 4)
        let changed = try IslandSleepProbeContext(source: source), session = try changed.session()
        defer { _ = session.shutdown() }
        let before = session.snapshot(), bytes = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        var refused = false
        do { _ = try session.restart(saved, codec: NativeRuntimeCheckpointCodec()) }
        catch let failure as RuntimeFailure {
            try require(failure.code == .incompatibleContinuation && failure.lastAccepted == before)
            refused = true
        }
        try require(refused && session.snapshot() == before && session.snapshot().checkpoint.random == before.checkpoint.random)
        try require(try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) == bytes)
    }

    @inline(never)
    private static func verifyPublicIslandSequenceRefusal(_ context: IslandSleepProbeContext,
        session: IslandSleepProbeContext.Session) throws {
        let accepted = session.snapshot(), original = accepted.checkpoint
        let malformed = try RuntimeCheckpoint(model: original.model, continuation: original.continuation,
            physical: original.physical, contributors: original.contributors,
            random: original.random, acceptedSteps: original.acceptedSteps + 1)
        let before = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        let invalid = try NativeRuntimeCheckpointCodec().encode(malformed, capacity: context.configuration.capacity)
        var refused = false
        do { _ = try session.restart(invalid, codec: NativeRuntimeCheckpointCodec()) }
        catch let failure as RuntimeFailure {
            try require(failure.code == .invalidContributor && failure.lastAccepted == accepted)
            refused = true
        }
        try require(refused && session.snapshot() == accepted)
        try require(try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) == before)
    }

    private static func verifyIslandSleepWork(_ context: IslandSleepProbeContext, work: IslandSleepWork) throws {
        let numerical = work.physical.numerical, loads = work.physical.loads, encoding = work.contributorEncoding
        try require(numerical.operations <= numerical.budget.arithmeticOperations
            && numerical.peakScalarStorage <= numerical.budget.scalarStorage && numerical.iterations <= numerical.budget.iterations)
        try require(loads.consumed <= loads.budget.maximumWork && loads.peakScalars <= loads.budget.maximumScalars)
        try require(encoding.operations <= encoding.budget.arithmeticOperations
            && encoding.peakScalarStorage <= encoding.budget.scalarStorage && encoding.iterations <= encoding.budget.iterations)
        try require(work.supplierInvocations <= context.operationPolicy.maximumSupplierInvocations
            && work.queries <= context.operationPolicy.maximumQueries)
        try require(!work.failedSupplierWorkUnavailable && !work.physical.failedSupplierWorkUnavailable)
    }

    private static func verifyIslandSleepAdvanceReceipt(_ result: IslandSleepAdvanceResult, caller: IslandSleepWork) throws {
        try require(result.work.physical.numerical == caller.physical.numerical
            && result.work.physical.loads.consumed == caller.physical.loads.consumed
            && result.work.physical.loads.peakScalars == caller.physical.loads.peakScalars
            && result.work.contributorEncoding == caller.contributorEncoding
            && result.work.supplierInvocations == caller.supplierInvocations && result.work.queries == caller.queries)
        try require(!result.work.failedSupplierWorkUnavailable && !result.integration.work.failedSupplierWorkUnavailable)
    }
}
