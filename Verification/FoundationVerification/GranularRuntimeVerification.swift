import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifyGranularRuntime() throws {
        let context = try GranularRuntimeProbeContext()
        defer { _ = context.session.shutdown() }
        try verifyGranularRuntimeAccepted(context)
        let expected = try granularRuntimeExpected(context)
        try verifyGranularRuntimeFresh(expected)
        try verifyGranularRuntimeSourceRefusal(expected.checkpoint)
        print("Granular Runtime public verification passed: physical shear, rejected history/RNG and fresh original-physics replay.")
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyGranularRuntimeAccepted(_ context: GranularRuntimeProbeContext) throws {
        let prefix = context.session.snapshot()
        let rejected = try granularRuntimeTrial(context, decision: .reject)
        try require(rejected.0.accepted == prefix && context.session.snapshot() == prefix)
        let accepted = try granularRuntimeTrial(context)
        try require(accepted.0.accepted.checkpoint.random.draws == 1)
        try verifyGranularRuntimePhysics(context, report: accepted.1)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func granularRuntimeExpected(_ context: GranularRuntimeProbeContext) throws -> GranularRuntimeReplayEvidence {
        let checkpoint = try context.checkpoint()
        let uninterrupted = try granularRuntimeTrial(context)
        let final = try context.checkpoint()
        return GranularRuntimeReplayEvidence(checkpoint: checkpoint, accepted: uninterrupted.0.accepted,
            particles: uninterrupted.1.state, final: final)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func granularRuntimeTrial(_ context: GranularRuntimeProbeContext,
        decision: RuntimeTrialDecision = .accept) throws -> (RuntimeTrialOutcome, GranularStepResult) {
        let recorder = GranularRuntimeProbeRecorder()
        let outcome = try context.session.performTrial {
            (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            var work: GranularRuntimeWork
            do { work = try context.work() }
            catch { throw RuntimeFailure(.invalidInput, message: "Granular public work construction failed.") }
            let report = try context.operation.advance(model: context.fixture.carrier, duration: 0.001,
                trial: &trial, control: &control, work: &work)
            recorder.record(report)
            return decision
        }
        guard let report = recorder.report() else { throw FoundationVerificationError.analyticCheckFailed }
        return (outcome, report)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyGranularRuntimePhysics(_ context: GranularRuntimeProbeContext,
        report: GranularStepResult) throws {
        let initial = context.fixture.initial
        try require(report.contacts.count == 3 && report.state.steps == 1 && report.state.timeSeconds == 0.001)
        var random = initial.random
        let draw = try random.next()
        let gravity = context.fixture.source.gravityChoices[Int(draw % 2)]
        var forces = [Vector3](), torques = [Vector3](repeating: .zero, count: 2)
        for particle in initial.model.particles { forces.append(try gravity.scaled(by: particle.mass)) }
        var bristleChanged = false
        var planeContacts = 0, separatedPairs = 0
        for contact in report.contacts {
            let binding = initial.model.bindings[contact.bindingIndex]
            if binding.secondParticle != nil {
                try require(abs(contact.separation - 1) < 1e-9)
                try require(contact.response.compressiveNormalForce == 0 && contact.response.forceOnB == .zero && contact.response.coupleOnB == .zero)
                separatedPairs += 1
                continue
            }
            planeContacts += 1
            try require(abs(contact.response.compressiveNormalForce - 10) < 1e-9)
            try require(binding.secondParticle == nil && binding.boundary != nil)
            let index = binding.firstParticle
            let force = try contact.response.forceOnB.scaled(by: -1)
            forces[index] = try forces[index].adding(force)
            let lever = try contact.point.subtracting(initial.motions[index].position)
            torques[index] = try lever.cross(force).subtracting(contact.response.coupleOnB)
            let history = report.state.contacts[contact.bindingIndex].history
            bristleChanged = bristleChanged || abs(history.firstBristleDisplacement) + abs(history.secondBristleDisplacement) > 1e-8
        }
        try require(planeContacts == 2 && separatedPairs == 1)
        var energyChange = 0.0, midpointWork = 0.0
        for index in initial.motions.indices {
            let old = initial.motions[index], next = report.state.motions[index], particle = initial.model.particles[index]
            let impulse = try next.velocity.subtracting(old.velocity).scaled(by: particle.mass)
            let expected = try forces[index].scaled(by: 0.001)
            let angularImpulse = try next.angularVelocity.subtracting(old.angularVelocity).scaled(by: particle.momentOfInertia)
            let expectedAngular = try torques[index].scaled(by: 0.001)
            try require(abs(impulse.x - expected.x) < 1e-9 && abs(impulse.y - expected.y) < 1e-9 && abs(impulse.z - expected.z) < 1e-9)
            try require(abs(angularImpulse.x - expectedAngular.x) < 1e-9 && abs(angularImpulse.y - expectedAngular.y) < 1e-9 && abs(angularImpulse.z - expectedAngular.z) < 1e-9)
            let oldSpeed = try old.velocity.dot(old.velocity), speed = try next.velocity.dot(next.velocity)
            let oldSpin = try old.angularVelocity.dot(old.angularVelocity), spin = try next.angularVelocity.dot(next.angularVelocity)
            energyChange += 0.5*particle.mass*(speed - oldSpeed) + 0.5*particle.momentOfInertia*(spin - oldSpin)
            midpointWork += 0.0005*(try forces[index].dot(old.velocity.adding(next.velocity)))
            midpointWork += 0.0005*(try torques[index].dot(old.angularVelocity.adding(next.angularVelocity)))
        }
        try require(bristleChanged && abs(energyChange - midpointWork) < 1e-9)
        try require(abs(report.evidence.kineticEnergyChange - energyChange) < 1e-9)
        try require(abs(report.evidence.particleMidpointWork - midpointWork) < 1e-9)
        var work = try context.work()
        let records = context.session.snapshot().checkpoint.contributors
        try require(records.count == 1)
        let decoded = try context.journal.decode(records[0], work: &work)
        try require(decoded.random == random && decoded.gravityChoiceIndices == [draw % 2])
        try require(GranularProbeContext.same(decoded.particles, report.state))
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyGranularRuntimeFresh(_ expected: GranularRuntimeReplayEvidence) throws {
        let fresh = try GranularRuntimeProbeContext()
        defer { _ = fresh.session.shutdown() }
        try verifyGranularRuntimeFreshModel(fresh, expected: expected)
        try granularRuntimeRestart(fresh, checkpoint: expected.checkpoint)
        let replay = try granularRuntimeReplayed(fresh, checkpoint: expected.checkpoint)
        try verifyGranularRuntimeReplayResult(replay, expected: expected)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyGranularRuntimeFreshModel(_ fresh: GranularRuntimeProbeContext,
        expected: GranularRuntimeReplayEvidence) throws {
        try require(fresh.fixture.initial.model !== expected.particles.model)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func granularRuntimeRestart(_ fresh: GranularRuntimeProbeContext, checkpoint: [UInt8]) throws {
        _ = try fresh.session.restart(checkpoint, codec: NativeRuntimeCheckpointCodec())
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func granularRuntimeReplayed(_ fresh: GranularRuntimeProbeContext,
        checkpoint: [UInt8]) throws -> GranularRuntimeReplayEvidence {
        let replay = try granularRuntimeTrial(fresh)
        let final = try fresh.checkpoint()
        return GranularRuntimeReplayEvidence(checkpoint: checkpoint, accepted: replay.0.accepted,
            particles: replay.1.state, final: final)
    }

    @inline(never)
    private static func verifyGranularRuntimeReplayResult(_ replay: GranularRuntimeReplayEvidence,
        expected: GranularRuntimeReplayEvidence) throws {
        let particles = expected.particles
        try require(replay.accepted == expected.accepted && replay.particles.motions == particles.motions)
        try require(replay.particles.steps == particles.steps && replay.particles.timeSeconds.bitPattern == particles.timeSeconds.bitPattern)
        try require(replay.particles.random == particles.random && replay.particles.contacts.count == particles.contacts.count)
        for index in particles.contacts.indices {
            try require(replay.particles.contacts[index].history == particles.contacts[index].history)
            try require(replay.particles.contacts[index].basis == particles.contacts[index].basis)
        }
        try require(replay.final == expected.final)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyGranularRuntimeSourceRefusal(_ checkpoint: [UInt8]) throws {
        let changed = try GranularRuntimeProbeContext(particleMass: 2)
        defer { _ = changed.session.shutdown() }
        let prefix = changed.session.snapshot()
        var refused = false
        do throws(RuntimeFailure) {
            _ = try changed.session.restart(checkpoint, codec: NativeRuntimeCheckpointCodec())
        } catch {
            try require(error.code == .incompatibleContinuation && error.lastAccepted == prefix)
            refused = true
        }
        try require(refused && changed.session.snapshot() == prefix)
    }
}
