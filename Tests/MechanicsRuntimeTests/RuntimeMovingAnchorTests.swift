import SwiftMechanics
import Testing

@Suite struct RuntimeMovingAnchorTests {
    @Test func actualMovingSampleAndExactRestartAdvance() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let model = try RuntimeMovingAnchorFixtures.model(), first = try RuntimeMovingAnchorFixtures.session(model: model)
        let resumed = try RuntimeMovingAnchorFixtures.session(model: model), codec = NativeRuntimeCheckpointCodec()
        for _ in 0..<3 { _ = try RuntimeMovingAnchorFixtures.advance(first) }
        let saved = first.snapshot(), bytes = try first.checkpoint(codec: codec)
        #expect(bytes[4] == 2)
        let decoded = try codec.decode(bytes, capacity: first.configuration.capacity)
        #expect(RuntimeMovingAnchorFixtures.bits(decoded.physical) == RuntimeMovingAnchorFixtures.bits(saved.physical.state))
        #expect(decoded.physical.prescribedAnchors.map { $0.frame } == saved.physical.state.prescribedAnchors.map { $0.frame })
        #expect(try codec.encode(decoded, capacity: first.configuration.capacity) == bytes)
        _ = try resumed.restart(bytes, codec: codec)
        #expect(try resumed.checkpoint(codec: codec) == bytes)
        #expect(first.profile().reservedPhysicalScalars == 43)
        let snapshot = try model.evaluate(resumed.snapshot().physical)
        let base = try snapshot.body(RuntimeFixtures.id(.body, "moving-base")).motion
        let t = saved.physical.state.time
        #expect(abs(base.pose.translation.x - (0.2 + 0.6 * t + 0.15 * t * t)) < 1e-12)
        #expect(abs(base.pose.translation.y) < 1e-12 && abs(base.pose.translation.z) < 1e-12)
        let reference = try UnitQuaternion(axis: .unitZ, angle: 0.3 + 0.4 * t + 0.1 * t * t), r = base.pose.rotation
        #expect(abs(abs(r.w * reference.w + r.x * reference.x + r.y * reference.y + r.z * reference.z) - 1) < 1e-12)
        #expect(abs(base.velocity.angular.z - (0.4 + 0.2 * t)) < 1e-12)
        #expect(abs(base.velocity.linear.x - (0.6 + 0.3 * t)) < 1e-12)
        #expect(abs(base.acceleration.angular.z - 0.2) < 1e-12 && abs(base.acceleration.linear.x - 0.3) < 1e-12)
        #expect(abs(base.velocity.angular.x) + abs(base.velocity.angular.y) + abs(base.velocity.linear.y) + abs(base.velocity.linear.z) < 1e-12)
        #expect(abs(base.acceleration.angular.x) + abs(base.acceleration.angular.y) + abs(base.acceleration.linear.y) + abs(base.acceleration.linear.z) < 1e-12)
        for _ in 0..<3 { _ = try RuntimeMovingAnchorFixtures.advance(first); _ = try RuntimeMovingAnchorFixtures.advance(resumed) }
        #expect(try first.checkpoint(codec: codec) == resumed.checkpoint(codec: codec))
        #expect(first.snapshot().checkpoint.random == resumed.snapshot().checkpoint.random)
    }
    @Test func rejectionCancellationAndResetPreserveWholeSavedPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let first = try RuntimeMovingAnchorFixtures.session(), control = try RuntimeMovingAnchorFixtures.session(), codec = NativeRuntimeCheckpointCodec()
        _ = try RuntimeMovingAnchorFixtures.advance(first); _ = try RuntimeMovingAnchorFixtures.advance(control)
        let prefix = first.snapshot(), bytes = try first.checkpoint(codec: codec), frame = try RuntimeMovingAnchorFixtures.frame()
        let replacement = try RuntimeMovingAnchorFixtures.sample(time: 99)
        _ = try first.performTrial { (trial: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) in
            _ = try trial.nextRandom(); try trial.setTime(99); try trial.setPosition(99, at: 0)
            try trial.setPrescribedAnchor(replacement); try trial.replaceContributor(CounterRuntimeContributors.record(99)); return .reject
        }
        #expect(try first.checkpoint(codec: codec) == bytes)
        RuntimeFixtures.failure(.cancelled) { () throws(RuntimeFailure) in
            _ = try first.performTrial { (trial: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) in
                _ = try trial.nextRandom(); try trial.setPrescribedAnchor(replacement); first.cancel(); return .accept
            }
        }
        #expect(first.snapshot() == prefix && first.snapshot().checkpoint.random == prefix.checkpoint.random)
        #expect(try first.checkpoint(codec: codec) == bytes)
        let expected = prefix.physical.state.prescribedAnchors[1].motion.pose.translation.x
        _ = try first.performTrial { (trial: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) in
            guard try trial.prescribedAnchor(frame).motion.pose.translation.x == expected else { throw RuntimeFailure(.invalidOwnerAccess, message: "Rejected/cancelled sample leaked into reset.") }
            return .reject
        }
        _ = try RuntimeMovingAnchorFixtures.advance(first); _ = try RuntimeMovingAnchorFixtures.advance(control)
        #expect(try first.checkpoint(codec: codec) == control.checkpoint(codec: codec))
    }
    @Test func actualCompiledFrameSetAndTimeRejectMalformedSourceWithoutAcceptance() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let model = try RuntimeMovingAnchorFixtures.model(), session = try RuntimeMovingAnchorFixtures.session(model: model), handler = try RuntimeFixtures.handler()
        let configuration = session.configuration, original = session.snapshot().checkpoint, codec = NativeRuntimeCheckpointCodec()
        let samples = original.physical.prescribedAnchors
        let unknown = try PrescribedAnchorState(frame: RuntimeFixtures.id(.frame, "unknown"), time: 0, motion: samples[1].motion)
        let stale = try PrescribedAnchorState(frame: samples[1].frame, time: 1, motion: samples[1].motion)
        let bad = try [RuntimeMovingAnchorFixtures.checkpoint(original, anchors: []),
            RuntimeMovingAnchorFixtures.checkpoint(original, anchors: [samples[0], unknown]),
            RuntimeMovingAnchorFixtures.checkpoint(original, anchors: [samples[0], stale]),
            RuntimeMovingAnchorFixtures.checkpoint(original, anchors: [samples[0], samples[0]])]
        for value in bad {
            var admitted: RuntimeAcceptedState?
            RuntimeFixtures.failure(.invalidState) { () throws(RuntimeFailure) in
                admitted = try handler.admit(value, model: model, configuration: configuration, cancellation: nil)
            }
            #expect(admitted == nil)
        }
        let prefix = try session.checkpoint(codec: codec)
        for value in bad.dropLast() {
            let bytes = try codec.encode(value, capacity: configuration.capacity)
            RuntimeFixtures.failure(.invalidState) { () throws(RuntimeFailure) in _ = try session.restart(bytes, codec: codec) }
            #expect(try session.checkpoint(codec: codec) == prefix)
        }
        RuntimeFixtures.failure(.invalidInput) { () throws(RuntimeFailure) in
            _ = try session.performTrial { (trial: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) in
                try trial.setPrescribedAnchor(unknown); return .accept
            }
        }
        RuntimeFixtures.failure(.invalidState) { () throws(RuntimeFailure) in
            _ = try session.performTrial { (trial: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) in
                _ = try trial.nextRandom(); try trial.setTime(0.25); return .accept
            }
        }
        #expect(try session.checkpoint(codec: codec) == prefix)
    }
    @Test func genuineLowerAdmissionCannotAlterSignedZeroOrQuaternionRepresentative() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let model = try RuntimeMovingAnchorFixtures.model(), configuration = try RuntimeFixtures.configuration(), lower = try RuntimeFixtures.handler()
        let records = try [CounterRuntimeContributors.record(0)], codec = NativeRuntimeCheckpointCodec()
        for quaternion in [false, true] {
            let handler = BitAlteringRuntimeCheckpointHandler(lower: lower, quaternion: quaternion)
            let session = try RuntimeSession(model: model, configuration: configuration, initialState: model.descriptor.initialState,
                contributors: records, seed: 42, checkpoints: handler)
            let prefix = session.snapshot(), bytes = try session.checkpoint(codec: codec)
            RuntimeFixtures.failure(.invalidOwnerAccess) { () throws(RuntimeFailure) in _ = try RuntimeMovingAnchorFixtures.advance(session) }
            #expect(session.snapshot() == prefix && session.snapshot().checkpoint.random == prefix.checkpoint.random)
            #expect(try session.checkpoint(codec: codec) == bytes)
        }
    }
    @Test func expectedSourceSignedZeroMismatchRefusesAtomicReplacement() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let source = try RuntimeMovingAnchorFixtures.model(), target = try RuntimeMovingAnchorFixtures.model(revision: 2)
        let session = try RuntimeMovingAnchorFixtures.session(model: source), handler = try RuntimeFixtures.handler(), codec = NativeRuntimeCheckpointCodec()
        let prefix = session.snapshot(), bytes = try session.checkpoint(codec: codec)
        var samples = prefix.physical.state.prescribedAnchors
        samples[1] = try RuntimeMovingAnchorFixtures.altered(samples[1], quaternion: false)
        let different = try RuntimeMovingAnchorFixtures.checkpoint(prefix.checkpoint, anchors: samples)
        #expect(different == prefix.checkpoint)
        #expect(try codec.encode(different, capacity: session.configuration.capacity) != bytes)
        let request = RuntimeModelReplacement(expectedSource: different, model: target, physical: target.descriptor.initialState,
            contributors: prefix.checkpoint.contributors, configuration: session.configuration, checkpoints: handler)
        RuntimeFixtures.failure(.incompatibleModel) { () throws(RuntimeFailure) in _ = try session.replaceModel(request) }
        #expect(session.snapshot().checkpoint.random == prefix.checkpoint.random)
        #expect(try session.checkpoint(codec: codec) == bytes)
        let valid = RuntimeModelReplacement(expectedSource: prefix.checkpoint, model: target, physical: target.descriptor.initialState,
            contributors: prefix.checkpoint.contributors, configuration: session.configuration, checkpoints: handler)
        _ = try session.replaceModel(valid)
        #expect(session.snapshot().physical.stamp == target.stamp && session.profile().reservedPhysicalScalars == 43)
        _ = try RuntimeMovingAnchorFixtures.advance(session)
        #expect(session.snapshot().physical.state.prescribedAnchors.count == 2)
    }
}
