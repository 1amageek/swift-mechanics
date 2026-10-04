import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) static func verifyHybrid() throws {
        print("Hybrid verification: constructing bound runtime sessions.")
        let context = try HybridProbeContext()
        defer { _ = context.first.shutdown(); _ = context.second.shutdown() }
        print("Hybrid verification: checking analytic bounce and impulse.")
        try verifyHybridBounce(context)
        print("Hybrid verification: checking checkpoint replay.")
        try verifyHybridReplay(context)
        print("Hybrid verification: checking cancelled-state preservation.")
        try verifyHybridCancellation(context)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func verifyHybridBounce(_ context: HybridProbeContext) throws {
        let result = try runHybridBounce(context)
        try checkHybridBounce(context, result: result)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func runHybridBounce(_ context: HybridProbeContext) throws -> HybridEvolutionResult {
        let service: any HybridEvolving = context.evolution
        return try service.advance(context.first, to: 0.6, work: context.work(), cancellation: context.cancellation)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func checkHybridBounce(_ context: HybridProbeContext, result: HybridEvolutionResult) throws {
        let hit = (0.2).squareRoot(), rebound = 5 * hit, elapsed = 0.6 - hit
        try require(result.impacts.count == 1 && abs(result.impacts[0].timeSeconds - hit) < 1e-9)
        let jump = result.impacts[0]
        try require(abs(jump.normalImpulses[0] - 30 * hit) < 1e-7)
        try require(abs(jump.kineticEnergyBefore - 20) < 1e-7 && abs(jump.kineticEnergyAfter - 5) < 1e-7 && abs(jump.predictedEnergyLoss - 15) < 1e-7)
        try require(abs(result.accepted.checkpoint.physical.q[0] - (0.5 + rebound * elapsed - 5 * elapsed * elapsed)) < 1e-7)
        try require(abs(result.accepted.checkpoint.physical.v[0] - (rebound - 10 * elapsed)) < 1e-7)
        try require(result.accepted.checkpoint.random == context.second.snapshot().checkpoint.random && result.accepted.checkpoint.acceptedSteps == 2)
        guard let record = result.accepted.checkpoint.contributors.first(where: { $0.id == context.history.schema.id }) else { throw FoundationVerificationError.analyticCheckFailed }
        let history = try context.history.associatedHistory(record, physical: result.accepted.checkpoint.physical)
        try require(history.impactGroups == 1 && history.lastEventIDs == [10] && result.work.trajectoryDerivativeCalls > 0)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func verifyHybridReplay(_ context: HybridProbeContext) throws {
        try restartHybridReplay(context)
        print("Hybrid replay: restart accepted.")
        let left = try advanceHybridReplay(context, session: context.first)
        print("Hybrid replay: uninterrupted evolution accepted.")
        let right = try advanceHybridReplay(context, session: context.second)
        print("Hybrid replay: restarted evolution accepted.")
        try checkHybridReplay(context, left: left, right: right)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func restartHybridReplay(_ context: HybridProbeContext) throws {
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        _ = try context.second.restart(context.first.checkpoint(codec: codec), codec: codec)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func advanceHybridReplay(_ context: HybridProbeContext, session: any RuntimeSessionOperating) throws -> HybridProbeResult {
        let service: any HybridEvolving = context.evolution
        return HybridProbeResult(try service.advance(session, to: 0.92, work: context.work(), cancellation: context.cancellation))
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func checkHybridReplay(_ context: HybridProbeContext, left leftOwner: HybridProbeResult, right rightOwner: HybridProbeResult) throws {
        let left = leftOwner.result, right = rightOwner.result
        try require(left.accepted == right.accepted && left.impacts.count == 1 && abs(left.impacts[0].timeSeconds - 2 * (0.2).squareRoot()) < 2e-9)
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        try require(try context.first.checkpoint(codec: codec) == context.second.checkpoint(codec: codec))
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func verifyHybridCancellation(_ context: HybridProbeContext) throws {
        let prefix = context.first.snapshot(), work = try context.work()
        context.cancellation.cancel()
        var rejected = false
        do throws(HybridEvolutionFailure) {
            _ = try context.evolution.advance(context.first, to: 1, work: work, cancellation: context.cancellation)
        } catch {
            switch error.cause { case .cancelled: rejected = true; default: throw FoundationVerificationError.unexpectedFailure }
            try require(error.lastAccepted == prefix)
        }
        try require(rejected && context.first.snapshot() == prefix)
    }
}
