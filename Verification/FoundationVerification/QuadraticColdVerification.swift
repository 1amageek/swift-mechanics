import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyQuadraticColdAuthority() throws {
        let context = try QuadraticColdProbeContext(fixture: QuadraticColdProbeModel())
        try verifyQuadraticReleaseBalance(context)
        try verifyQuadraticColdReplay(context)
        try verifyQuadraticRestingSourceBinding(context)
        print("AF26 quadratic cold authority: retained-row force, sixDOF release, strict source/history and exact replay passed")
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyQuadraticReleaseBalance(_ context: QuadraticColdProbeContext) throws {
        let physical = context.reconciled.physical
        try require(physical.q == context.release.incomingPhysical.q
            && physical.v == context.release.incomingPhysical.v
            && physical.time.bitPattern == context.release.incomingPhysical.time.bitPattern
            && physical.revision == context.release.target.stamp.revision)
        try require(abs(physical.acceleration[context.bVelocity]+1) < 1e-8
            && abs(physical.acceleration[context.cVelocity]+1) < 1e-8)
        for index in context.freeVelocities.start..<(context.freeVelocities.start+context.freeVelocities.count) {
            try require(abs(physical.acceleration[index]) < 1e-8)
        }
        try require(context.reconciled.motion.generalizedReaction.count == physical.v.count)
        // F_B=-4 plus reaction +2; F_C=0 plus reaction -2, with actual masses 2.
        try require(abs(context.reconciled.motion.generalizedReaction[context.bVelocity]-2) < 1e-8
            && abs(context.reconciled.motion.generalizedReaction[context.cVelocity]+2) < 1e-8)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func advanceQuadraticCold(_ context: QuadraticColdProbeContext,
                                            session: QuadraticColdProbeContext.Session, to time: Double) throws {
        _ = try context.step(session, to: time)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func restartQuadraticCold(_ session: QuadraticColdProbeContext.Session, bytes: [UInt8]) throws {
        _ = try session.restart(bytes, codec: NativeRuntimeCheckpointCodec())
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyQuadraticColdReplay(_ context: QuadraticColdProbeContext) throws {
        let session = try context.session()
        defer { _ = session.shutdown() }
        try advanceQuadraticCold(context, session: session, to: 0.02)
        let saved = try context.checkpoint(session)
        try advanceQuadraticCold(context, session: session, to: 0.04)
        try verifyQuadraticMotion(context, session: session, time: 0.04)
        let finalBytes = try context.checkpoint(session)
        try restartQuadraticCold(session, bytes: saved)
        try advanceQuadraticCold(context, session: session, to: 0.04)
        try require(try context.checkpoint(session) == finalBytes)
        try verifyQuadraticFreshReplay(saved, finalBytes: finalBytes)
        try verifyQuadraticForgedForce(context, session: session)
        try verifyQuadraticForgedSequence(context, session: session)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyQuadraticMotion(_ context: QuadraticColdProbeContext,
                                             session: QuadraticColdProbeContext.Session, time: Double) throws {
        let physical = session.snapshot().checkpoint.physical
        for (position, velocity) in [(context.bPosition, context.bVelocity), (context.cPosition, context.cVelocity)] {
            try require(abs(physical.q[position]+0.5*time*time) < 1e-8)
            try require(abs(physical.v[velocity]+time) < 1e-8 && abs(physical.acceleration[velocity]+1) < 1e-8)
        }
        for index in context.freePositions.start..<(context.freePositions.start+context.freePositions.count) {
            try require(physical.q[index].bitPattern == context.reconciled.physical.q[index].bitPattern)
        }
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyQuadraticFreshReplay(_ saved: [UInt8], finalBytes: [UInt8]) throws {
        let fresh = try QuadraticColdProbeContext(fixture: QuadraticColdProbeModel())
        let session = try fresh.session()
        defer { _ = session.shutdown() }
        try restartQuadraticCold(session, bytes: saved)
        try advanceQuadraticCold(fresh, session: session, to: 0.04)
        try require(try fresh.checkpoint(session) == finalBytes)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyQuadraticForgedForce(_ context: QuadraticColdProbeContext,
                                                 session: QuadraticColdProbeContext.Session) throws {
        let prefix = session.snapshot(), old = prefix.checkpoint
        let saved = try context.checkpoint(session)
        var acceleration = old.physical.acceleration
        acceleration[context.bVelocity] += 0.25; acceleration[context.cVelocity] += 0.25
        let forged = try KinematicState(revision: old.physical.revision, time: old.physical.time,
            q: old.physical.q, v: old.physical.v, acceleration: acceleration)
        let checkpoint = try RuntimeCheckpoint(model: old.model, continuation: old.continuation,
            physical: forged, contributors: old.contributors, random: old.random, acceptedSteps: old.acceptedSteps)
        let codec = NativeRuntimeCheckpointCodec()
        let bytes = try codec.encode(checkpoint, capacity: session.configuration.capacity)
        var refused = false
        do throws(RuntimeFailure) { _ = try session.restart(bytes, codec: codec) }
        catch { try require(error.code == .invalidState); refused = true }
        try require(refused && session.snapshot() == prefix && (try context.checkpoint(session)) == saved)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyQuadraticForgedSequence(_ context: QuadraticColdProbeContext,
                                                    session: QuadraticColdProbeContext.Session) throws {
        let prefix = session.snapshot(), old = prefix.checkpoint
        let checkpoint = try RuntimeCheckpoint(model: old.model, continuation: old.continuation,
            physical: old.physical, contributors: old.contributors, random: old.random, acceptedSteps: old.acceptedSteps+1)
        let codec = NativeRuntimeCheckpointCodec()
        let bytes = try codec.encode(checkpoint, capacity: session.configuration.capacity)
        var refused = false
        do throws(RuntimeFailure) { _ = try session.restart(bytes, codec: codec) }
        catch { try require(error.code == .invalidContributor); refused = true }
        try require(refused && session.snapshot() == prefix)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyQuadraticRestingSourceBinding(_ context: QuadraticColdProbeContext) throws {
        let sourceContinuation = try QuadraticColdProbeContext.continuation(context.sourceEquations)
        let sourceHandler = try QuadraticColdProbeContext.handler(equations: context.sourceEquations,
            continuation: sourceContinuation)
        let initial = context.fixture.model.descriptor.initialState
        let source = try QuadraticColdProbeContext.Session(model: context.fixture.model,
            configuration: QuadraticColdProbeContext.configuration(sourceContinuation), initialState: initial,
            contributors: [sourceContinuation.initialRecord(physical: initial, equations: context.sourceEquations)],
            seed: 42, checkpoints: sourceHandler)
        defer { _ = source.shutdown() }
        let bytes = try source.checkpoint(codec: NativeRuntimeCheckpointCodec())
        let changed = try QuadraticColdProbeModel(mass: 3)
        let equation = try QuadraticColdProbeContext.sourceEquation(changed)
        let provider = try QuadraticColdProbeContext.continuation(equation)
        let handler = try QuadraticColdProbeContext.handler(equations: equation, continuation: provider)
        let foreign = try QuadraticColdProbeContext.Session(model: changed.model,
            configuration: QuadraticColdProbeContext.configuration(provider), initialState: changed.model.descriptor.initialState,
            contributors: [provider.initialRecord(physical: changed.model.descriptor.initialState, equations: equation)],
            seed: 42, checkpoints: handler)
        defer { _ = foreign.shutdown() }
        let prefix = foreign.snapshot()
        try require(prefix.checkpoint.physical == source.snapshot().checkpoint.physical)
        try require(prefix.checkpoint.model == source.snapshot().checkpoint.model)
        var refused = false
        do throws(RuntimeFailure) { _ = try foreign.restart(bytes, codec: NativeRuntimeCheckpointCodec()) }
        catch { try require(error.code == .incompatibleContinuation); refused = true }
        try require(refused && foreign.snapshot() == prefix)
    }
}
