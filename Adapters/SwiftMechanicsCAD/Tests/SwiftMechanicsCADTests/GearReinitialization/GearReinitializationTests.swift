import Testing
import CADCore
import CADIR
import SwiftMechanics
import SwiftMechanicsCAD

@Suite struct GearReinitializationTests {
    @Test(.timeLimit(.minutes(1)))
    func actualResizeRebuildPhysicalReinitializeAndFreshRestart() throws {
        guard #available(macOS 15, *) else { return }
        let recipe = try GearReinitializationFixtures(), source = try recipe.context()
        let session = try GearReinitializationFixtures.session(source)
        try GearReinitializationFixtures.draw(session, context: source)
        _ = try ProjectedNonlinearMechanismEvolution().advance(session, equations: source.equations,
            continuation: source.continuation, to: 0.01)
        let before = session.snapshot().checkpoint
        #expect(before.random.draws == 1)
        let edited = try GearReinitializationFixtures(document: GearReinitializationFixtures.resized(recipe.document),
            scale: 1.1, revision: 2, secondInertia: 5)
        let prepared = try edited.prepare(source: source, expected: before)
        let publisher: any CADGearReinitializationPublishing = ReferenceCADGearReinitializationPublisher()
        let accepted = try publisher.publish(prepared, in: session)
        #expect(accepted.checkpoint == prepared.checkpoint)
        #expect(accepted.checkpoint.random == before.random)
        #expect(accepted.checkpoint.acceptedSteps == before.acceptedSteps + 1)
        #expect(accepted.checkpoint.physical.time.bitPattern == before.physical.time.bitPattern)
        #expect(accepted.checkpoint.physical.q == [0, 0])
        #expect(accepted.checkpoint.physical.v == [2, -1])
        #expect(abs(accepted.checkpoint.physical.acceleration[0] - 4.0 / 13) < 1e-9)
        #expect(abs(accepted.checkpoint.physical.acceleration[1] + 2.0 / 13) < 1e-9)
        #expect(abs(prepared.target.binding.first.dimensions[.pitchRadius]! - 0.022) < 1e-12)
        #expect(abs(prepared.target.binding.second.dimensions[.pitchRadius]! - 0.044) < 1e-12)
        let second = try #require(prepared.target.model.initialSnapshot.bodies.first { $0.body.key == "second" })
        #expect(abs(second.motion.pose.translation.x - 0.066) < 1e-12)
        #expect(prepared.target.model.descriptor != source.model.descriptor)
        #expect(prepared.target.equations.descriptor.chart != source.equations.descriptor.chart)
        #expect(prepared.target.contributors.record.bytes != source.contributors.record.bytes)
        let integration = try #require(accepted.checkpoint.contributors.first { $0.id == prepared.target.continuation.schema.id })
        let history = try prepared.target.continuation.history(integration)
        #expect(history.acceptedSteps == accepted.checkpoint.acceptedSteps)
        #expect(history.nextStep == prepared.target.continuation.policy.initialStep)
        #expect(history.acceptedPoint == [0, 0, 2, -1])
        let codec = NativeRuntimeCheckpointCodec(), saved = try session.checkpoint(codec: codec)
        // This fixture stores only public source declarations and policies, no admitted model/state.
        let cold = try edited.context(time: before.physical.time)
        #expect(cold !== prepared.target)
        #expect(cold.equations !== prepared.target.equations)
        #expect(cold.binding.geometry !== prepared.target.binding.geometry)
        let fresh = try GearReinitializationFixtures.session(cold)
        #expect(fresh.snapshot().checkpoint.acceptedSteps == 0)
        let restored = try fresh.restart(saved, codec: codec)
        #expect(restored.checkpoint == accepted.checkpoint)
        #expect(try fresh.checkpoint(codec: codec) == saved)
        _ = try ProjectedNonlinearMechanismEvolution().advance(session, equations: prepared.target.equations,
            continuation: prepared.target.continuation, to: 0.02)
        _ = try ProjectedNonlinearMechanismEvolution().advance(fresh, equations: cold.equations,
            continuation: cold.continuation, to: 0.02)
        #expect(fresh.snapshot().checkpoint == session.snapshot().checkpoint)
        #expect(try fresh.checkpoint(codec: codec) == session.checkpoint(codec: codec))
        let point = fresh.snapshot().checkpoint.physical
        #expect(abs(point.v[0] - (2 + (4.0 / 13) * 0.01)) < 1e-9)
        #expect(abs(point.v[1] - (-1 - (2.0 / 13) * 0.01)) < 1e-9)
        let energy = try GearReinitializationFixtures.energy(cold, physical: point)
        #expect(abs(energy.kineticEnergy - (6.5 + 2 * 0.01 + (2.0 / 13) * 0.01 * 0.01)) < 1e-9)
        #expect(abs(energy.kineticEnergyRate - point.v[0]) < 1e-9)
        #expect(abs(point.acceleration[0] - 4.0 / 13) < 1e-9)
        #expect(abs(point.acceleration[1] + 2.0 / 13) < 1e-9)
    }

    @Test(.timeLimit(.minutes(1)))
    func staleSourceChoiceGeometryForceAndCapacityRefuseWithoutPublication() throws {
        guard #available(macOS 15, *) else { return }
        let recipe = try GearReinitializationFixtures(), source = try recipe.context()
        let session = try GearReinitializationFixtures.session(source), before = session.snapshot().checkpoint
        let codec = NativeRuntimeCheckpointCodec(), bytes = try session.checkpoint(codec: codec)
        let document = try GearReinitializationFixtures.resized(recipe.document)
        let good = try GearReinitializationFixtures(document: document, scale: 1.1, revision: 2)
        do { _ = try good.prepare(source: source, expected: before, choice: .preserveCompatibleState); Issue.record("Missing migration authority was accepted.") }
        catch let error as CADGearReinitializationError {
            guard case .unsupportedMigration = error else { throw error }
        }
        let unchanged = try GearReinitializationFixtures(document: recipe.document, revision: 2)
        #expect(GearReinitializationFixtures.refuses { _ = try unchanged.prepare(source: source, expected: before) })
        let stale = try GearReinitializationFixtures(document: document, scale: 1.1, revision: 1)
        #expect(GearReinitializationFixtures.refuses { _ = try stale.prepare(source: source, expected: before) })
        let spacing = try GearReinitializationFixtures(document: document, scale: 1.1, revision: 2, spacing: 0.06)
        #expect(GearReinitializationFixtures.refuses { _ = try spacing.prepare(source: source, expected: before) })
        let force = try GearReinitializationFixtures(document: document, scale: 1.1, revision: 2, acceleration: [0, 0])
        #expect(GearReinitializationFixtures.refuses { _ = try force.prepare(source: source, expected: before) })
        var exhausted = try CADAdapterWork(maximumVisits: 1), numerical = try GearBindingFixtures.work()
        #expect(GearReinitializationFixtures.refuses {
            _ = try ReferenceCADGearReinitializationPreparer().prepare(source: source, expectedSource: before,
                document: good.document, occurrences: good.occurrences, tolerance: CADFixtures.tolerance,
                limits: CADFixtures.limits(), recipe: good.builder, choice: .reinitialize,
                work: &exhausted, transmissionWork: &numerical)
        })
        #expect(session.snapshot().checkpoint == before)
        #expect(try session.checkpoint(codec: codec) == bytes)
    }

    @Test(.timeLimit(.minutes(1)))
    func realPublicationRejectsStaleCompleteCheckpointAndKeepsDrawPrefix() throws {
        guard #available(macOS 15, *) else { return }
        let recipe = try GearReinitializationFixtures(), source = try recipe.context()
        let session = try GearReinitializationFixtures.session(source)
        let edit = try GearReinitializationFixtures(document: GearReinitializationFixtures.resized(recipe.document), scale: 1.1, revision: 2)
        let prepared = try edit.prepare(source: source, expected: session.snapshot().checkpoint)
        try GearReinitializationFixtures.draw(session, context: source)
        let before = session.snapshot().checkpoint, codec = NativeRuntimeCheckpointCodec()
        let bytes = try session.checkpoint(codec: codec)
        do { _ = try ReferenceCADGearReinitializationPublisher().publish(prepared, in: session); Issue.record("Stale whole source published.") }
        catch {
            guard case .runtime(let cause) = error else { throw error }
            #expect(cause.code == .incompatibleModel)
            #expect(cause.lastAccepted?.checkpoint == before)
        }
        #expect(before.random.draws == 1)
        #expect(session.snapshot().checkpoint == before)
        #expect(try session.checkpoint(codec: codec) == bytes)
    }

    @Test(.timeLimit(.minutes(1)))
    func strictRecipeForceGlobalHistoryAndCatalogRestartRefusal() throws {
        guard #available(macOS 15, *) else { return }
        let recipe = try GearReinitializationFixtures(), source = try recipe.context()
        let session = try GearReinitializationFixtures.session(source)
        try GearReinitializationFixtures.draw(session, context: source)
        let before = session.snapshot().checkpoint, codec = NativeRuntimeCheckpointCodec()
        let original = try session.checkpoint(codec: codec)
        var badBytes = source.contributors.record.bytes; badBytes[badBytes.count - 1] ^= 1
        let altered = try RuntimeContributorState(id: source.contributors.schema.id, category: .backend, version: 1, bytes: badBytes)
        let integration = try #require(before.contributors.first { $0.id == source.continuation.schema.id })
        let extra = try RuntimeContributorState(id: "unsupported.actuator.history", category: .actuator, version: 1, bytes: [1])
        let badHistory = try source.continuation.record(acceptedTime: before.physical.time, point: [0, 0, 2, -1],
            nextStep: source.continuation.policy.initialStep, acceptedSteps: 0, normalizedError: nil)
        let catalogs = [[altered, integration], [source.contributors.record],
            [source.contributors.record, integration, integration], [source.contributors.record, integration, extra],
            [source.contributors.record, badHistory]]
        for records in catalogs {
            let checkpoint = try RuntimeCheckpoint(model: before.model, continuation: before.continuation,
                physical: before.physical, contributors: records, random: before.random, acceptedSteps: before.acceptedSteps)
            let encoded = try codec.encode(checkpoint, capacity: source.configuration.capacity)
            #expect(GearReinitializationFixtures.refuses { _ = try session.restart(encoded, codec: codec) })
            #expect(session.snapshot().checkpoint == before)
            #expect(try session.checkpoint(codec: codec) == original)
        }
        let wrong = try KinematicState(revision: before.model.revision, time: before.physical.time,
            q: before.physical.q, v: before.physical.v, acceleration: [0, 0])
        let forged = try RuntimeCheckpoint(model: before.model, continuation: before.continuation, physical: wrong,
            contributors: before.contributors, random: before.random, acceptedSteps: before.acceptedSteps)
        let forceBytes = try codec.encode(forged, capacity: source.configuration.capacity)
        #expect(GearReinitializationFixtures.refuses { _ = try session.restart(forceBytes, codec: codec) })
        let changedRecipe = try GearReinitializationFixtures.RecipeBuilder(revision: 1, spacing: 0.06,
            secondInertia: 5, acceleration: nil).makeRecipe(geometry: source.binding.geometry, time: 0)
        let changed = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(changedRecipe.descriptor, policy: changedRecipe.compilation)
        #expect(GearReinitializationFixtures.refuses {
            _ = try source.checkpoints.admit(before, model: changed, configuration: source.configuration, cancellation: nil)
        })
        // This is a genuine admitted same-source context with physically acceptable but different initial recipe bits.
        let alpha = (4.0 / 11).nextUp
        let differentInitial = try GearReinitializationFixtures(document: recipe.document,
            acceleration: [alpha, -alpha / 2], material: recipe.occurrences[0].material)
        let differentContext = try differentInitial.context()
        let other = try GearReinitializationFixtures.session(differentContext)
        let otherPrefix = try other.checkpoint(codec: codec)
        #expect(GearReinitializationFixtures.refuses { _ = try other.restart(original, codec: codec) })
        #expect(try other.checkpoint(codec: codec) == otherPrefix)
        #expect(try session.checkpoint(codec: codec) == original)
        #expect(session.snapshot().checkpoint.random == before.random)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelledActualPublicationAndOldRevisionRestartKeepWholePrefix() async throws {
        guard #available(macOS 15, *) else { return }
        let recipe = try GearReinitializationFixtures(), source = try recipe.context()
        let session = try GearReinitializationFixtures.session(source)
        let before = session.snapshot().checkpoint, codec = NativeRuntimeCheckpointCodec()
        let old = try session.checkpoint(codec: codec)
        let edit = try GearReinitializationFixtures(document: GearReinitializationFixtures.resized(recipe.document), scale: 1.1, revision: 2)
        let prepared = try edit.prepare(source: source, expected: before)
        let cancelled = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do { _ = try ReferenceCADGearReinitializationPublisher().publish(prepared, in: session); return false }
            catch { return true }
        }.value
        #expect(cancelled)
        #expect(session.snapshot().checkpoint == before)
        #expect(try session.checkpoint(codec: codec) == old)
        _ = try ReferenceCADGearReinitializationPublisher().publish(prepared, in: session)
        let final = session.snapshot().checkpoint, saved = try session.checkpoint(codec: codec)
        #expect(GearReinitializationFixtures.refuses { _ = try session.restart(old, codec: codec) })
        #expect(session.snapshot().checkpoint == final)
        #expect(try session.checkpoint(codec: codec) == saved)
    }
}
