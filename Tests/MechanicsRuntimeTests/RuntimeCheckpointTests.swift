import Testing
import MechanicsCompiler
import MechanicsJoints
import MechanicsRuntime

@Suite struct RuntimeCheckpointTests {
    @Test func actualCheckpointRestartMatchesUninterruptedContinuation() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let model = try RuntimeFixtures.model(), first = try RuntimeFixtures.session(model: model), resumed = try RuntimeFixtures.session(model: model)
        for _ in 0..<3 { _ = try RuntimeFixtures.advance(first) }
        let codec = NativeRuntimeCheckpointCodec(), bytes = try first.checkpoint(codec: codec)
        _ = try resumed.restart(bytes, codec: codec)
        #expect(first.snapshot() == resumed.snapshot())
        for _ in 0..<5 { _ = try RuntimeFixtures.advance(first); _ = try RuntimeFixtures.advance(resumed) }
        #expect(first.snapshot() == resumed.snapshot())
        #expect(try first.checkpoint(codec: codec) == resumed.checkpoint(codec: codec))
    }
    @Test func corruptTruncatedTrailingAndMissingDataAreTransactional() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let session = try RuntimeFixtures.session(); _ = try RuntimeFixtures.advance(session)
        let codec = NativeRuntimeCheckpointCodec(), bytes = try session.checkpoint(codec: codec), prefix = session.snapshot()
        var corrupt = bytes; corrupt[corrupt.count-1] ^= 1
        RuntimeFixtures.failure(.corruptCheckpoint) { () throws(RuntimeFailure) in _ = try session.restart(corrupt, codec: codec) }
        let oldRecord = prefix.checkpoint
        let metadata = [oldRecord.model.identity, oldRecord.continuation.build, oldRecord.continuation.backend, oldRecord.continuation.precision]
        let stateOffset = 28 + metadata.reduce(0) { $0 + 8 + $1.utf8.count } + 8 + 8 + 8
        var inconsistentRandom = bytes; inconsistentRandom[stateOffset] ^= 1
        let repaired = RuntimeFixtures.repairedChecksum(inconsistentRandom)
        RuntimeFixtures.failure(.corruptCheckpoint) { () throws(RuntimeFailure) in _ = try session.restart(repaired, codec: codec) }
        var invalidUTF8 = bytes; invalidUTF8[36] = 255
        let invalidText = RuntimeFixtures.repairedChecksum(invalidUTF8)
        RuntimeFixtures.failure(.corruptCheckpoint) { () throws(RuntimeFailure) in _ = try session.restart(invalidText, codec: codec) }
        let truncated = Array(bytes.dropLast())
        RuntimeFixtures.failure(.truncatedCheckpoint) { () throws(RuntimeFailure) in _ = try session.restart(truncated, codec: codec) }
        let trailing = bytes + [0]
        RuntimeFixtures.failure(.corruptCheckpoint) { () throws(RuntimeFailure) in _ = try session.restart(trailing, codec: codec) }
        let old = prefix.checkpoint
        let missing = try RuntimeCheckpoint(model: old.model, continuation: old.continuation, physical: old.physical, contributors: [], random: old.random, acceptedSteps: old.acceptedSteps)
        let missingBytes = try codec.encode(missing, capacity: session.configuration.capacity)
        RuntimeFixtures.failure(.missingContributor) { () throws(RuntimeFailure) in _ = try session.restart(missingBytes, codec: codec) }
        #expect(session.snapshot() == prefix)
    }
    @Test func modelAndBuildBackendCompatibilityAreDistinct() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let session = try RuntimeFixtures.session(), codec = NativeRuntimeCheckpointCodec(), original = session.snapshot().checkpoint
        let physical = try KinematicState(revision: 2, time: 0, q: original.physical.q, v: original.physical.v, acceleration: original.physical.acceleration)
        let stale = try RuntimeCheckpoint(model: ModelStamp(identity: original.model.identity, revision: 2), continuation: original.continuation,
            physical: physical, contributors: original.contributors, random: original.random, acceptedSteps: 0)
        let staleBytes = try codec.encode(stale, capacity: session.configuration.capacity)
        RuntimeFixtures.failure(.incompatibleModel) { () throws(RuntimeFailure) in _ = try session.restart(staleBytes, codec: codec) }
        for continuation in [try RuntimeContinuationIdentity(build: "other-build", backend: original.continuation.backend, precision: "float64"),
                             try RuntimeContinuationIdentity(build: original.continuation.build, backend: "other-backend", precision: "float64")] {
            let mismatch = try RuntimeCheckpoint(model: original.model, continuation: continuation, physical: original.physical,
                contributors: original.contributors, random: original.random, acceptedSteps: 0)
            let bytes = try codec.encode(mismatch, capacity: session.configuration.capacity)
            RuntimeFixtures.failure(.incompatibleContinuation) { () throws(RuntimeFailure) in _ = try session.restart(bytes, codec: codec) }
        }
        #expect(session.snapshot().checkpoint == original)
    }
    @Test func requiredProviderAndContributorMigrationUseActualData() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let source = try RuntimeFixtures.model(), target = try RuntimeFixtures.model(revision: 2, mass: 2), handler = try RuntimeFixtures.handler()
        let session = try RuntimeFixtures.session(model: source); _ = try RuntimeFixtures.advance(session)
        let transition = try ReferenceModelRevisionUpdater().transition(from: source, to: target, policy: .preserveIfKinematicsUnchanged)
        let migrated = try handler.migrate(session.snapshot().checkpoint, from: source, to: target, using: transition, configuration: session.configuration)
        #expect(migrated.physical.revision == 2 && migrated.physical.q == session.snapshot().physical.state.q)
        #expect(migrated.contributors == session.snapshot().checkpoint.contributors && migrated.random == session.snapshot().checkpoint.random)
        let fresh = try RuntimeFixtures.session(model: target)
        _ = try fresh.restart(NativeRuntimeCheckpointCodec().encode(migrated, capacity: fresh.configuration.capacity), codec: NativeRuntimeCheckpointCodec())
        #expect(fresh.snapshot().checkpoint == migrated)
        let empty = ReferenceRuntimeCheckpointHandler(contributors: NoRuntimeContributors(), revisions: ReferenceModelRevisionUpdater())
        RuntimeFixtures.failure(.missingContributor) { () throws(RuntimeFailure) in
            _ = try empty.admit(session.snapshot().checkpoint, model: source, configuration: session.configuration, cancellation: nil)
        }
    }
    @Test func byteAndPhysicalCapacityRejectBeforeSuccess() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let model = try RuntimeFixtures.model(), config = try RuntimeFixtures.configuration(capacity: RuntimeFixtures.capacity(physical: 2))
        let handler = try RuntimeFixtures.handler(), states = try [CounterRuntimeContributors.record(0)]
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in
            _ = try RuntimeFixtures.Session(model: model, configuration: config, initialState: model.descriptor.initialState, contributors: states, seed: 0, checkpoints: handler)
        }
        let session = try RuntimeFixtures.session(), small = try RuntimeFixtures.capacity(bytes: 16)
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in _ = try NativeRuntimeCheckpointCodec().encode(session.snapshot().checkpoint, capacity: small) }
    }
}
