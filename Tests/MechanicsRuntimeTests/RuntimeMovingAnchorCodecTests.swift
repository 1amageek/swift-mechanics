import SwiftMechanics
import Testing

@Suite struct RuntimeMovingAnchorCodecTests {
    @Test func zeroAnchorV1BytesRemainTheFrozenHistoricalFixture() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let session = try RuntimeFixtures.session(), codec = NativeRuntimeCheckpointCodec()
        // A fixed, independently specified v1 byte fixture; no current encoder constructs this oracle.
        let expected: [UInt8] = [
            83, 77, 82, 84, 1, 0, 0, 0, 0, 0, 0, 0, 230, 0, 0, 0, 0, 0, 0, 0,
            104, 49, 133, 7, 59, 146, 215, 249, 13, 0, 0, 0, 0, 0, 0, 0, 114, 117, 110, 116,
            105, 109, 101, 45, 109, 111, 100, 101, 108, 1, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0,
            0, 0, 0, 0, 0, 102, 105, 120, 116, 117, 114, 101, 45, 118, 49, 13, 0, 0, 0, 0,
            0, 0, 0, 114, 101, 102, 101, 114, 101, 110, 99, 101, 45, 99, 112, 117, 7, 0, 0, 0,
            0, 0, 0, 0, 102, 108, 111, 97, 116, 54, 52, 0, 0, 0, 0, 0, 0, 0, 0, 42,
            0, 0, 0, 0, 0, 0, 0, 42, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
            0, 0, 0, 0, 0, 0, 0, 18, 0, 0, 0, 0, 0, 0, 0, 105, 110, 116, 101, 103,
            114, 97, 116, 111, 114, 45, 99, 111, 117, 110, 116, 101, 114, 5, 1, 0, 0, 0, 0, 0,
            0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ]
        #expect(try session.checkpoint(codec: codec) == expected)
        let decoded = try codec.decode(expected, capacity: session.configuration.capacity)
        #expect(decoded == session.snapshot().checkpoint && decoded.physical.prescribedAnchors.isEmpty)
        _ = try session.restart(expected, codec: codec)
        #expect(try session.checkpoint(codec: codec) == expected)
    }
    @Test func signedZeroTimeCoordinatesAndAllSampleScalarsSurviveExactRestoration() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let model = try RuntimeMovingAnchorFixtures.model(), configuration = try RuntimeFixtures.configuration(), handler = try RuntimeFixtures.handler()
        let initial = try KinematicState(revision: 1, time: -0.0, q: [-0.0], v: [-0.0], acceleration: [-0.0],
            prescribedAnchors: [RuntimeMovingAnchorFixtures.sample(time: -0.0, secondary: true), RuntimeMovingAnchorFixtures.sample(time: -0.0)])
        let owner = try RuntimeFixtures.Session(model: model, configuration: configuration, initialState: initial,
            contributors: [CounterRuntimeContributors.record(0)], seed: 42, checkpoints: handler)
        let codec = NativeRuntimeCheckpointCodec(), bytes = try owner.checkpoint(codec: codec)
        let decoded = try codec.decode(bytes, capacity: configuration.capacity)
        #expect(RuntimeMovingAnchorFixtures.bits(decoded.physical) == RuntimeMovingAnchorFixtures.bits(initial))
        #expect(decoded.physical.time.bitPattern == (-0.0).bitPattern)
        #expect(decoded.physical.prescribedAnchors[1].motion.pose.rotation.w < 0)
        _ = try owner.restart(bytes, codec: codec)
        #expect(try owner.checkpoint(codec: codec) == bytes)
        _ = try RuntimeMovingAnchorFixtures.advance(owner)
        #expect(owner.snapshot().physical.state.time == 0.25)
    }
    @Test func twentySlotsPerAnchorAreEnforcedAcrossCodecAdmissionAndOwner() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let model = try RuntimeMovingAnchorFixtures.model(), capacity = try RuntimeFixtures.capacity(physical: 43)
        let owner = try RuntimeMovingAnchorFixtures.session(model: model, capacity: capacity), codec = NativeRuntimeCheckpointCodec()
        let bytes = try owner.checkpoint(codec: codec), tooSmall = try RuntimeFixtures.capacity(physical: 42)
        let configuration = try RuntimeFixtures.configuration(capacity: tooSmall), handler = try RuntimeFixtures.handler()
        let records = try [CounterRuntimeContributors.record(0)]
        #expect(owner.profile().reservedPhysicalScalars == 43)
        #expect(RuntimeMovingAnchorFixtures.bits(try codec.decode(bytes, capacity: capacity).physical) == RuntimeMovingAnchorFixtures.bits(owner.snapshot().physical.state))
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in _ = try codec.decode(bytes, capacity: tooSmall) }
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in _ = try codec.encode(owner.snapshot().checkpoint, capacity: tooSmall) }
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in
            _ = try RuntimeFixtures.Session(model: model, configuration: configuration, initialState: model.descriptor.initialState,
                contributors: records, seed: 42, checkpoints: handler)
        }
        // Configuration metadata fits, but model + both frame keys + actual registry/state identifiers do not.
        let metadataCapacity = try RuntimeCapacity(maximumPhysicalScalars: 43, maximumContributors: 8, maximumContributorBytes: 128,
            maximumMetadataBytes: 80, maximumCheckpointBytes: 4096, maximumValidationWork: 64, maximumValidationScratchBytes: 64,
            maximumObservationLeases: 2, maximumBatchStates: 8, maximumTransactions: 1000, maximumStepWorkUnits: 100, maximumWorkBetweenSafePoints: 4)
        let smallMetadataConfiguration = try RuntimeFixtures.configuration(capacity: metadataCapacity)
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in _ = try codec.decode(bytes, capacity: metadataCapacity) }
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in _ = try codec.encode(owner.snapshot().checkpoint, capacity: metadataCapacity) }
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in
            _ = try handler.admit(owner.snapshot().checkpoint, model: model, configuration: smallMetadataConfiguration, cancellation: nil)
        }
    }
    @Test func malformedVersionTwoFieldsNeverReplaceAcceptedPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let owner = try RuntimeMovingAnchorFixtures.session(), codec = NativeRuntimeCheckpointCodec()
        _ = try RuntimeMovingAnchorFixtures.advance(owner)
        let prefix = owner.snapshot(), bytes = try owner.checkpoint(codec: codec), checkpoint = prefix.checkpoint
        let strings = [checkpoint.model.identity, checkpoint.continuation.build, checkpoint.continuation.backend, checkpoint.continuation.precision]
        let anchorCountOffset = 28 + strings.reduce(0) { $0 + 8 + $1.utf8.count } + 8 + 32 + 8 + 24 + 24
        let scalarOffset = anchorCountOffset + 8 + 8 + checkpoint.physical.prescribedAnchors[0].frame.key.utf8.count
        var zeroCount = bytes, invalidRotation = bytes, nonfinite = bytes, inflatedCount = bytes
        for index in 0..<8 {
            zeroCount[anchorCountOffset + index] = 0
            inflatedCount[anchorCountOffset + index] = UInt8(truncatingIfNeeded: UInt64.max >> (8 * index))
            invalidRotation[scalarOffset + 8 + index] = UInt8(truncatingIfNeeded: 2.0.bitPattern >> (8 * index))
            nonfinite[scalarOffset + 5 * 8 + index] = UInt8(truncatingIfNeeded: Double.infinity.bitPattern >> (8 * index))
        }
        let malformed = [RuntimeFixtures.repairedChecksum(zeroCount), RuntimeFixtures.repairedChecksum(invalidRotation), RuntimeFixtures.repairedChecksum(nonfinite)]
        for input in malformed {
            RuntimeFixtures.failure(.corruptCheckpoint) { () throws(RuntimeFailure) in _ = try owner.restart(input, codec: codec) }
            #expect(try owner.checkpoint(codec: codec) == bytes)
        }
        let oversized = RuntimeFixtures.repairedChecksum(inflatedCount)
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in _ = try owner.restart(oversized, codec: codec) }
        let duplicate = try RuntimeMovingAnchorFixtures.checkpoint(checkpoint, anchors: [checkpoint.physical.prescribedAnchors[0], checkpoint.physical.prescribedAnchors[0]])
        let duplicateBytes = try codec.encode(duplicate, capacity: owner.configuration.capacity)
        RuntimeFixtures.failure(.corruptCheckpoint) { () throws(RuntimeFailure) in _ = try owner.restart(duplicateBytes, codec: codec) }
        RuntimeFixtures.failure(.truncatedCheckpoint) { () throws(RuntimeFailure) in _ = try owner.restart(Array(bytes.dropLast()), codec: codec) }
        #expect(owner.snapshot() == prefix && owner.snapshot().checkpoint.random == prefix.checkpoint.random)
        #expect(try owner.checkpoint(codec: codec) == bytes)
    }
}
