import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifySampledControl() throws {
        try verifyControlHeldInterval()
        try verifyControlDisturbance()
        try verifyControlComputedTorque()
        try verifyControlContinuation()
        try verifyControlRefusals()
        try verifyControlPhysicalRejection()
        try verifyControlCancellation()
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlHeldInterval() throws {
        let context = try ControlProbeContext(), session = try context.makeSession()
        defer { _ = session.shutdown() }
        let initial = try context.observation(session)
        try require(!initial.controller.issued && initial.controller.tick == 0 && initial.accepted.checkpoint.acceptedSteps == 0)
        let result = try session.step(input: context.input(initial))
        try verifyControlMotion(result, position: 0.0075, rate: 0.15, acceleration: 1.5, kinetic: 0.0225)
        let history = result.observation.controller
        try require(abs(history.heldEffort - 3) < 1e-12 && abs(history.actuatorIntervalWork - 0.0225) < 1e-12)
        try require(history.nominalSampledWork == 0 && history.initialKineticEnergy == 0 && history.disturbanceIntervalWork == 0)
        try require(try context.observation(session).accepted == result.observation.accepted)
        try require(result.actuationWork.used > 0 && result.integration.work.supplierArithmeticCharged > 0)
        try require(session.shutdown() == .closed && session.shutdownStatus() == .closed)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlDisturbance() throws {
        let context = try ControlProbeContext(disturbance: -1), session = try context.makeSession()
        defer { _ = session.shutdown() }
        let result = try session.step(input: context.input(context.observation(session)))
        try verifyControlMotion(result, position: 0.005, rate: 0.1, acceleration: 1, kinetic: 0.01)
        let history = result.observation.controller
        try require(abs(history.actuatorIntervalWork - 0.015) < 1e-12)
        try require(abs(history.disturbanceIntervalWork + 0.005) < 1e-12)
        try require(abs(history.endpointKineticEnergy - history.initialKineticEnergy - history.actuatorIntervalWork - history.disturbanceIntervalWork) < 1e-12)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlComputedTorque() throws {
        let context = try ControlProbeContext(disturbance: -1, computedTorque: true), session = try context.makeSession()
        defer { _ = session.shutdown() }
        let result = try session.step(input: context.input(context.observation(session), computed: true))
        try verifyControlMotion(result, position: 0.0035, rate: 0.07, acceleration: 0.7, kinetic: 0.0049)
        let history = result.observation.controller
        try require(abs(history.requestedEffort - 2.4) < 1e-12 && abs(history.heldEffort - 2.4) < 1e-12)
        try require(!history.clipped && abs(history.actuatorIntervalWork - 0.0084) < 1e-12)
        try require(abs(history.disturbanceIntervalWork + 0.0035) < 1e-12)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlMotion(_ result: ControlStepResult, position: Double, rate: Double,
                                          acceleration: Double, kinetic: Double) throws {
        let observation = result.observation, physical = observation.accepted.checkpoint.physical
        try require(result.integration.reachedRequestedTime && result.integration.acceptedSteps == 1 && result.integration.rejectedTrials == 0)
        try require(physical.time == 0.1 && physical.q.count == 1 && physical.v.count == 1 && physical.acceleration.count == 1)
        try require(abs(physical.q[0] - position) < 1e-12 && abs(physical.v[0] - rate) < 1e-12)
        try require(abs(physical.acceleration[0] - acceleration) < 1e-12)
        try require(observation.controller.tick == 1 && observation.controller.issued && !observation.controller.pending)
        try require(observation.actuator.time == physical.time && observation.actuator.sequence == 1)
        try require(observation.accepted.checkpoint.acceptedSteps == 1 && observation.accepted.checkpoint.random.draws == 0)
        try require(abs(observation.controller.endpointKineticEnergy - kinetic) < 1e-12 && abs(observation.controller.forceResidual) < 1e-12)
        // The independently specified moving mass is 2 kg, so K = v squared in joules.
        try require(abs(observation.controller.endpointKineticEnergy - physical.v[0] * physical.v[0]) < 1e-12)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlContinuation() throws {
        let context = try ControlProbeContext(), first = try context.makeSession(), cold = try context.makeSession()
        defer { _ = first.shutdown(); _ = cold.shutdown() }
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        let firstStep = try advanceControlContinuation(context, session: first)
        let coldStep = try advanceControlContinuation(context, session: cold)
        try verifyControlContinuationMatch(firstStep, coldStep)
        let saved = try first.checkpoint(codec: codec)
        let next = try advanceControlContinuation(context, session: first, previous: firstStep)
        try verifyControlContinuationEndpoint(next)
        try first.restart(saved, codec: codec)
        try verifyControlContinuationRestored(context, session: first, expected: firstStep)
        let replay = try advanceControlContinuation(context, session: first)
        try verifyControlContinuationMatch(replay, next)
        try cold.restart(saved, codec: codec)
        let coldReplay = try advanceControlContinuation(context, session: cold)
        try verifyControlContinuationMatch(coldReplay, next)
        try require(try first.checkpoint(codec: codec) == cold.checkpoint(codec: codec))
        try verifyControlContinuationTruncation(context, session: first, saved: saved, codec: codec)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func controlContinuationInput(_ context: ControlProbeContext,
        session: any ControlSessionOperating, previous: ControlProbeStepRecord?) throws -> ControlSampleInput {
        if let previous { return try context.input(previous.result.observation) }
        return try context.input(context.observation(session))
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func advanceControlContinuation(_ context: ControlProbeContext,
        session: any ControlSessionOperating, previous: ControlProbeStepRecord? = nil) throws -> ControlProbeStepRecord {
        let input = try controlContinuationInput(context, session: session, previous: previous)
        return ControlProbeStepRecord(try session.step(input: input))
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlContinuationMatch(_ first: ControlProbeStepRecord,
        _ second: ControlProbeStepRecord) throws {
        try require(first.result.observation.accepted == second.result.observation.accepted)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlContinuationEndpoint(_ next: ControlProbeStepRecord) throws {
        try require(next.result.observation.controller.tick == 2 && next.result.observation.accepted.checkpoint.physical.time == 0.2)
        try require(abs(next.result.observation.accepted.checkpoint.physical.q[0] - 0.03) < 1e-12)
        try require(abs(next.result.observation.accepted.checkpoint.physical.v[0] - 0.3) < 1e-12)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlContinuationRestored(_ context: ControlProbeContext,
        session: any ControlSessionOperating, expected: ControlProbeStepRecord) throws {
        try require(try context.observation(session).accepted == expected.result.observation.accepted)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlContinuationTruncation(_ context: ControlProbeContext,
        session: any ControlSessionOperating, saved: [UInt8], codec: any RuntimeCheckpointCoding) throws {
        let before = try context.observation(session).accepted
        var refused = false
        do throws(ControlFailure) { try session.restart(Array(saved.dropLast()), codec: codec) }
        catch {
            guard case .runtime(let failure) = error.cause, failure.code == .truncatedCheckpoint else { throw FoundationVerificationError.unexpectedFailure }
            refused = true
        }
        try require(refused && context.observation(session).accepted == before)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlRefusals() throws {
        let context = try ControlProbeContext(), session = try context.makeSession()
        defer { _ = session.shutdown() }
        let before = try context.observation(session)
        let future = try context.input(before, tick: 1, sampleTime: 0.1)
        var clockRefused = false
        do throws(ControlFailure) { _ = try session.step(input: future) }
        catch { guard case .staleSample = error.cause else { throw FoundationVerificationError.unexpectedFailure }; clockRefused = true }
        let staleSource = try context.input(before, sourceTime: 0.1)
        var sourceRefused = false
        do throws(ControlFailure) { _ = try session.step(input: staleSource) }
        catch { guard case .staleSample = error.cause else { throw FoundationVerificationError.unexpectedFailure }; sourceRefused = true }
        try require(clockRefused && sourceRefused && context.observation(session).accepted == before.accepted)
        let recovery = try session.step(input: context.input(before))
        try verifyControlMotion(recovery, position: 0.0075, rate: 0.15, acceleration: 1.5, kinetic: 0.0225)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlPhysicalRejection() throws {
        let context = try ControlProbeContext(speedLimit: 0.1), session = try context.makeSession()
        defer { _ = session.shutdown() }
        let before = try context.observation(session)
        let input = try context.input(before)
        var refused = false
        do throws(ControlFailure) { _ = try session.step(input: input) }
        catch {
            guard case .originalEvidenceRejected = error.cause, error.phase == "endpoint-energy" else { throw FoundationVerificationError.unexpectedFailure }
            refused = true
        }
        try require(refused && context.observation(session).accepted == before.accepted)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyControlCancellation() throws {
        let context = try ControlProbeContext()
        let owner = ControlProbeContext.CancellationOwner()
        let drive = ControlProbeContext.CancellingDrive {
            owner.cancelAfterDrive()
        }
        let session = try context.makeSession(drives: drive)
        owner.install(session)
        defer { owner.clear(); _ = session.shutdown() }
        let before = try context.observation(session), input = try context.input(before)
        var refused = false
        do throws(ControlFailure) { _ = try session.step(input: input) }
        catch {
            switch error.cause {
            case .integration(let failure): try require(failure.cause.code == .cancelled)
            case .runtime(let failure): try require(failure.code == .cancelled)
            default: throw FoundationVerificationError.unexpectedFailure
            }
            refused = true
        }
        try require(refused && owner.invocationCount == 1 && context.observation(session).accepted == before.accepted)
    }
}
