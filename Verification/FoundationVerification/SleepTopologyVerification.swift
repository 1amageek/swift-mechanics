import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension FoundationVerification {
    @inline(never)
    static func verifySleepTopology() throws {
        let context = try SleepTopologyProbeContext(fixture: SleepTopologyProbeModel())
        let session = try context.session()
        defer { _ = session.shutdown() }
        let source = try context.sleepSource(session), saved = try context.checkpoint(session)
        try checkTopologyOriginalSleep(context, session: session, source: source)
        let prepared = try preparePublicSleepTopology(context, source: source)
        try require(session.snapshot() == source && (try context.checkpoint(session)) == saved)
        try checkSleepTopologyPreparationRefusals(context, prepared: prepared, session: session)
        let accepted = try context.publish(prepared, session: session)
        try checkSleepTopologyBoundary(context, prepared: prepared, accepted: accepted)
        try checkSleepTopologyReplay(context, prepared: prepared, session: session)
        try checkSleepTopologyStalePublication(prepared, session: session)
        print("AF26 public sleeping source retirement, retained physical coupling, global event/history and cold replay passed.")
    }

    @inline(never)
    private static func checkTopologyOriginalSleep(_ context: SleepTopologyProbeContext,
                                                   session: SleepTopologyProbeContext.Session,
                                                   source: RuntimeAcceptedState) throws {
        let physical = source.checkpoint.physical
        guard let record = source.checkpoint.contributors.first(where: { $0.id == context.sleep.schema.id }),
              let integration = source.checkpoint.contributors.first(where: { $0.id == context.sleep.continuation.schema.id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let history = try context.sleep.history(record), stored = try context.sleep.continuation.history(integration)
        try require(source.checkpoint.acceptedSteps == 2 && physical.time == 0.2)
        try require(history.asleep.allSatisfy { $0 } && history.acceptedSequence == source.checkpoint.acceptedSteps)
        try require(history.acceptedTime.bitPattern == physical.time.bitPattern && stored.acceptedSteps == source.checkpoint.acceptedSteps)
        try require(stored.acceptedPoint == physical.q + physical.v && physical.acceleration.allSatisfy { $0 == 0 })
        let equation = context.sourceEquations, a = context.fixture.aVelocity, b = context.fixture.bVelocity, c = context.fixture.cVelocity
        let budget = try SleepTopologyProbeContext.validationBudget()
        _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            var work = NumericalWork(budget: budget)
            var point = [Double](repeating: 0, count: equation.descriptor.dimensions.count)
            try equation.read(trial, into: &point)
            let motion = try equation.motion(time: trial.timeSeconds, point: point, work: &work, control: control)
            do {
                // Original masses 2, F_A=+4/F_B=-4, J_11=(1,-1,0), J_12=(0,1,-1).
                try require(motion.rowIDs == [11, 12] && motion.values.allSatisfy { abs($0) < 1e-9 })
                try require(abs(motion.generalizedReaction[a] + 4) < 1e-9)
                try require(abs(motion.generalizedReaction[b] - 4) < 1e-9 && abs(motion.generalizedReaction[c]) < 1e-9)
            } catch { throw RuntimeFailure(.invalidState, message: "Original sleeping equilibrium force witness failed.") }
            _ = try trial.nextRandom()
            return .reject
        }
        try require(session.snapshot() == source)
    }

    @inline(never)
    private static func preparePublicSleepTopology(_ context: SleepTopologyProbeContext,
                                                  source: RuntimeAcceptedState) throws -> PreparedSleepTopologyPublication {
        var work = try TopologyProbeContext.work(), dynamics = try TopologyProbeContext.work()
        let release = try context.release(source, work: &work, dynamicsWork: &dynamics)
        let equation = try context.equation(release)
        let retirement = try context.retire(source: source, release: release, equations: equation, work: &work)
        try require(retirement.source == source && retirement.release === release && retirement.retiredConstraintIDs == [11])
        try require(retirement.retiredEffort == 4 && !retirement.sourceLawSignature.isEmpty)
        try require(retirement.targetDrive == equation.drive && retirement.targetConstraints.rows.map { $0.id } == [12])
        let transition = try context.reconcile(release: release, equations: equation, work: &work)
        try checkSleepTopologyTargetPhysics(context, transition: transition)
        return try context.prepare(source: source, retirement: retirement, transition: transition, equations: equation, work: &work)
    }

    @inline(never)
    private static func checkSleepTopologyTargetPhysics(_ context: SleepTopologyProbeContext,
                                                       transition: NonlinearReconciledSubtreeRelease) throws {
        let release = transition.release, physical = transition.physical
        guard let b = release.target.tree.layout.joints.first(where: { $0.joint == context.fixture.bJoint }),
              let c = release.target.tree.layout.joints.first(where: { $0.joint == context.fixture.cJoint }),
              let free = release.target.tree.layout.joints.first(where: { $0.joint == release.connector }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        try require(physical.q == release.incomingPhysical.q && physical.v == release.incomingPhysical.v)
        try require(physical.time.bitPattern == release.source.state.time.bitPattern && free.positions.count == 7 && free.velocities.count == 6)
        try require(abs(physical.acceleration[b.velocities.start] + 1) < 1e-9 && abs(physical.acceleration[c.velocities.start] + 1) < 1e-9)
        try require(abs(transition.motion.generalizedReaction[b.velocities.start] - 2) < 1e-9)
        try require(abs(transition.motion.generalizedReaction[c.velocities.start] + 2) < 1e-9)
        for i in free.velocities.start..<(free.velocities.start + free.velocities.count) {
            try require(abs(physical.acceleration[i]) < 1e-9)
        }
    }

    @inline(never)
    private static func checkSleepTopologyBoundary(_ context: SleepTopologyProbeContext,
                                                   prepared: PreparedSleepTopologyPublication,
                                                   accepted: RuntimeAcceptedState) throws {
        let event = prepared.wake.event, checkpoint = accepted.checkpoint
        try require(prepared.handler.history.events == [event] && event.id == context.rule.id)
        try require(event.acceptedSequence == prepared.source.checkpoint.acceptedSteps + 1)
        try require(checkpoint.acceptedSteps == event.acceptedSequence && checkpoint.physical.time.bitPattern == event.acceptedTime.bitPattern)
        try require(checkpoint.physical == prepared.transition.physical && checkpoint.model == event.target)
        try require(event.source == prepared.source.checkpoint.model && event.target.revision == event.source.revision + 1)
        try require(checkpoint.random == prepared.source.checkpoint.random && checkpoint.contributors == prepared.contributors)
        try require(checkpoint.contributors.count == 3 && !checkpoint.contributors.contains { $0.id == context.sleep.schema.id })
        try require(checkpoint.contributors.contains(prepared.wake.record) && checkpoint.contributors.contains(prepared.handler.history.record))
        try checkSleepTopologyGlobalHistory(prepared, accepted: accepted)
        print("AF26 sleep topology payload bytes: law=\(prepared.retirement.sourceLawSignature.count), wake=\(prepared.wake.record.bytes.count), history=\(prepared.handler.history.record.bytes.count).")
    }

    private static func checkSleepTopologyGlobalHistory(_ prepared: PreparedSleepTopologyPublication,
                                                        accepted: RuntimeAcceptedState) throws {
        guard let record = accepted.checkpoint.contributors.first(where: { $0.id == prepared.continuation.schema.id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let stored = try prepared.continuation.history(record), physical = accepted.checkpoint.physical
        try require(stored.acceptedSteps == accepted.checkpoint.acceptedSteps)
        try require(stored.acceptedTime.bitPattern == physical.time.bitPattern && stored.acceptedPoint == physical.q + physical.v)
    }

    @inline(never)
    private static func checkSleepTopologyReplay(_ context: SleepTopologyProbeContext,
                                                 prepared: PreparedSleepTopologyPublication,
                                                 session: SleepTopologyProbeContext.Session) throws {
        let equation = try context.equation(prepared.transition.release)
        let time = prepared.source.checkpoint.physical.time
        _ = try context.step(session, equations: equation, continuation: prepared.continuation, to: time + 0.02)
        let saved = try context.checkpoint(session)
        let final = try context.step(session, equations: equation, continuation: prepared.continuation, to: time + 0.04).accepted
        try checkSleepTopologyGlobalHistory(prepared, accepted: final)
        try checkSleepTopologyEvolvedPhysics(context, prepared: prepared, equations: equation, session: session, elapsed: 0.04)
        let bytes = try context.checkpoint(session)
        _ = try session.restart(saved, codec: NativeRuntimeCheckpointCodec())
        try require(try context.step(session, equations: equation, continuation: prepared.continuation, to: time + 0.04).accepted == final)
        try require(try context.checkpoint(session) == bytes)
        try checkSleepTopologyFreshReplay(context, prepared: prepared, equations: equation, saved: saved, final: final, bytes: bytes)
        try checkSleepTopologyForgedPrefix(session)
    }

    @inline(never)
    private static func checkSleepTopologyEvolvedPhysics(_ context: SleepTopologyProbeContext,
                                                         prepared: PreparedSleepTopologyPublication,
                                                         equations: NonlinearMechanismEquation,
                                                         session: SleepTopologyProbeContext.Session, elapsed: Double) throws {
        let model = prepared.transition.release.target, state = session.snapshot().checkpoint.physical
        guard let b = model.tree.layout.joints.first(where: { $0.joint == context.fixture.bJoint }),
              let c = model.tree.layout.joints.first(where: { $0.joint == context.fixture.cJoint }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        for entry in [b, c] {
            try require(abs(state.q[entry.positions.start] + 0.5 * elapsed * elapsed) < 1e-9)
            try require(abs(state.v[entry.velocities.start] + elapsed) < 1e-9 && abs(state.acceleration[entry.velocities.start] + 1) < 1e-9)
        }
        let prefix = session.snapshot(), bytes = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        let budget = try SleepTopologyProbeContext.validationBudget()
        _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            var work = NumericalWork(budget: budget)
            var point = [Double](repeating: 0, count: equations.descriptor.dimensions.count)
            try equations.read(trial, into: &point)
            let proof = try equations.consistent(time: trial.timeSeconds, point: point, work: &work, control: control)
            do {
                // Both original masses are 2. Integrating F_B=-4 along q_B=-h²/2 yields work 2h².
                try require(abs(proof.kineticEnergy - 2 * elapsed * elapsed) < 1e-9)
                let reaction = proof.acceleration.generalizedReaction
                let reactionPower = reaction[b.velocities.start] * state.v[b.velocities.start] + reaction[c.velocities.start] * state.v[c.velocities.start]
                let drivePower = -4 * state.v[b.velocities.start]
                try require(abs(reactionPower) < 1e-9 && abs(drivePower - 4 * elapsed) < 1e-9)
                try require(abs(-4 * state.q[b.positions.start] - proof.kineticEnergy) < 1e-9)
            } catch { throw RuntimeFailure(.invalidState, message: "Independent retained physical coupling energy/work witness failed.") }
            _ = try trial.nextRandom()
            return .reject
        }
        try require(session.snapshot() == prefix && (try session.checkpoint(codec: NativeRuntimeCheckpointCodec())) == bytes)
    }

    @inline(never)
    private static func checkSleepTopologyFreshReplay(_ context: SleepTopologyProbeContext,
                                                      prepared: PreparedSleepTopologyPublication,
                                                      equations: NonlinearMechanismEquation, saved: [UInt8],
                                                      final: RuntimeAcceptedState, bytes: [UInt8]) throws {
        let fresh = try context.freshSession(prepared, equations: equations)
        defer { _ = fresh.shutdown() }
        _ = try fresh.restart(saved, codec: NativeRuntimeCheckpointCodec())
        try require(try context.step(fresh, equations: equations, continuation: prepared.continuation,
            to: final.checkpoint.physical.time).accepted == final)
        try require(try fresh.checkpoint(codec: NativeRuntimeCheckpointCodec()) == bytes)
        try require(fresh.snapshot().checkpoint.contributors.contains(prepared.wake.record))
    }

    @inline(never)
    private static func checkSleepTopologyPreparationRefusals(_ context: SleepTopologyProbeContext,
                                                             prepared: PreparedSleepTopologyPublication,
                                                             session: SleepTopologyProbeContext.Session) throws {
        let prefix = session.snapshot(), bytes = try context.checkpoint(session)
        let equation = try context.equation(prepared.transition.release)
        let service: any SleepTopologyTransitionPreparing = ReferenceSleepTopologyTransitionPreparer()
        let budget = try SleepTopologyProbeContext.validationBudget()
        let variants: [[SleepTopologyContributorDisposition]] = [[], [.appendHistory, .appendHistory,
                .initializeGlobalIntegration(retiredID: context.sleep.continuation.schema.id)]]
        for dispositions in variants {
            var work = try TopologyProbeContext.work(), refused = false
            try work.chargeOperations(5)
            do throws(TopologyReleaseFailure) {
                _ = try service.prepare(source: prepared.source, sourceConfiguration: prepared.sourceConfiguration,
                    retirement: prepared.retirement, transition: prepared.transition, history: context.history,
                    observation: .explicit(prepared.transition.release), ruleID: context.rule.id, dispositions: dispositions,
                    targetConfiguration: prepared.configuration, equations: equation, continuation: prepared.continuation,
                    validationBudget: budget, cancellation: nil, work: &work)
            } catch {
                guard case .staleSource = error else { throw FoundationVerificationError.analyticCheckFailed }
                refused = true
            }
            try require(refused && work.operations >= 5 && session.snapshot() == prefix && (try context.checkpoint(session)) == bytes)
        }
    }

    @inline(never)
    private static func checkSleepTopologyStalePublication(_ prepared: PreparedSleepTopologyPublication,
                                                          session: SleepTopologyProbeContext.Session) throws {
        let prefix = session.snapshot(), bytes = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        var refused = false
        do throws(TopologyReleaseFailure) { _ = try ReferenceSleepTopologyTransitionPreparer().publish(prepared, session: session) }
        catch { guard case .staleSource = error else { throw FoundationVerificationError.analyticCheckFailed }; refused = true }
        try require(refused && session.snapshot() == prefix && (try session.checkpoint(codec: NativeRuntimeCheckpointCodec())) == bytes)
    }

    @inline(never)
    private static func checkSleepTopologyForgedPrefix(_ session: SleepTopologyProbeContext.Session) throws {
        let prefix = session.snapshot(), old = prefix.checkpoint
        let codec = NativeRuntimeCheckpointCodec(), saved = try session.checkpoint(codec: codec)
        let forged = try RuntimeCheckpoint(model: old.model, continuation: old.continuation, physical: old.physical,
            contributors: old.contributors, random: old.random, acceptedSteps: old.acceptedSteps + 1)
        let bytes = try codec.encode(forged, capacity: session.configuration.capacity)
        var refused = false
        do throws(RuntimeFailure) { _ = try session.restart(bytes, codec: codec) }
        catch { try require(error.code == .invalidContributor); refused = true }
        try require(refused && session.snapshot() == prefix && (try session.checkpoint(codec: codec)) == saved)
    }
}
