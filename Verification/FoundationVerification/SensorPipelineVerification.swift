import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifySensorPipeline() throws {
        try verifySensorTimingAndProcessing()
        try verifySensorTrialRollbackAndReplay()
        try verifySensorColdSourceRefusal()
        try verifySensorReadyQueuePolicies()
        try verifySensorLeaseLifetime()
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifySensorTimingAndProcessing() throws {
        let context = try SensorPipelineProbeContext()
        defer { _ = context.session.shutdown() }
        let initial = try context.batch()
        try require(initial.records.isEmpty && initial.lastReadySequence == 0)
        try context.step()
        try require(try context.batch().records.isEmpty)
        try context.step()
        try require(try context.batch().records.isEmpty)
        try context.step()
        let batch = try context.batch()
        try require(batch.records.count == 5 && batch.lastReadySequence == 5 && batch.retainedAfter == 0)
        try batch.requireCompatible(schema: context.definition.schemaID, version: 1,
            channelIDs: context.definition.channels.map { $0.id },
            dimensions: context.definition.channels.map { $0.dimension })
        try verifySensorFirstRecords(batch, context: context)
        let physical = context.session.snapshot().checkpoint
        var expectedRandom = RuntimeRandomState(seed: 7)
        for _ in 0..<3 { _ = try expectedRandom.next() }
        try require(physical.acceptedSteps == 3 && physical.random.draws == 3)
        try require(physical.random == expectedRandom)
        try require(physical.physical.time == 0.375 && abs(physical.physical.q[0] - 0.890625) < 1e-10)
        try require(physical.physical.v == [2.75] && physical.physical.acceleration == [2])
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifySensorFirstRecords(_ batch: SensorBatch, context: SensorPipelineProbeContext) throws {
        for index in 0..<5 {
            let record = batch.records[index]
            try require(record.channelIndex == index && record.tick == 1 && record.sampleTime == 0.125)
            try require(record.sourceTime == 0.125 && record.releaseDeadline == 0.3125 && record.deliveryTime == 0.375)
            try require(record.readySequence == UInt64(index + 1) && !record.isInterpolated)
            try require(record.source.model == context.fixture.model.stamp && record.source.acceptedSequence == 1)
            try require(record.source.physical.time == 0.125 && record.source.physical.q == [0.265625])
            try require(record.source.physical.v == [2.25] && record.source.physical.acceleration == [2])
        }
        let noisy = batch.records[0]
        let expected = 0.265625 + 0.1 + (2 * SensorPipelineProbeContext.uniform(streamKey: 11, draw: 1) - 1) * 0.05
        try require(noisy.rawValue == 0.265625 && noisy.value == expected && !noisy.saturated)
        try require(batch.records[1].rawValue == 2.25 && batch.records[1].value == 2 && batch.records[1].saturated)
        try require(abs(batch.records[2].rawValue - 2) < 1e-10 && abs((batch.records[2].value ?? .nan) - 2) < 1e-10)
        try require(abs(batch.records[3].rawValue - 2.25) < 1e-10 && abs((batch.records[3].value ?? .nan) - 2.25) < 1e-10)
        try require(batch.records[4].rawValue == 2 && batch.records[4].isDropout && batch.records[4].value == nil)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifySensorTrialRollbackAndReplay() throws {
        let context = try SensorPipelineProbeContext()
        defer { _ = context.session.shutdown() }
        try context.step(); try context.step(); try context.step()
        let prefix = try context.checkpoint()
        let rejected = try context.session.performTrial { trial, control throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 1)
            _ = try trial.nextRandom()
            try trial.setPosition(99, at: 0); try trial.setVelocity(98, at: 0)
            try trial.setAcceleration(97, at: 0); try trial.setTime(0.5)
            return .reject
        }
        try require(rejected.decision == .reject && (try context.checkpoint()) == prefix)
        var cancelled = false
        do throws(RuntimeFailure) {
            _ = try context.session.performTrial { trial, control throws(RuntimeFailure) in
                _ = try trial.nextRandom(); try trial.setPosition(96, at: 0)
                context.session.cancel()
                try control.beginWorkBlock(units: 1)
                return .accept
            }
        } catch {
            try require(error.code == .cancelled)
            cancelled = true
        }
        try require(cancelled && (try context.checkpoint()) == prefix)
        try verifySensorFreshReplay(context, saved: prefix)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifySensorFreshReplay(_ original: SensorPipelineProbeContext, saved: [UInt8]) throws {
        let cold = try SensorPipelineProbeContext()
        defer { _ = cold.session.shutdown() }
        _ = try cold.session.restart(saved, codec: NativeRuntimeCheckpointCodec())
        try require(try cold.checkpoint() == saved)
        try original.step(); try cold.step()
        try original.step(); try cold.step()
        try require(try original.checkpoint() == cold.checkpoint())
        let first = try original.batch(), second = try cold.batch()
        try require(first.records.count == 15 && second.records.count == 15)
        for index in first.records.indices {
            let lhs = first.records[index], rhs = second.records[index]
            try require(lhs.readySequence == rhs.readySequence && lhs.tick == rhs.tick && lhs.value == rhs.value)
            try require(lhs.source.physical == rhs.source.physical && lhs.deliveryTime == rhs.deliveryTime)
        }
        for tick in 1...3 {
            let noisy = first.records[(tick - 1) * 5]
            let time = Double(tick) * 0.125
            let expected = 2 * time + time * time + 0.1
                + (2 * SensorPipelineProbeContext.uniform(streamKey: 11, draw: UInt64(2 * tick - 1)) - 1) * 0.05
            try require(noisy.value == expected)
        }
        try require(original.session.snapshot().checkpoint.random.draws == 5)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifySensorColdSourceRefusal() throws {
        let context = try SensorPipelineProbeContext()
        defer { _ = context.session.shutdown() }
        try context.step(); try context.step(); try context.step()
        let saved = try context.checkpoint()
        let forged = try context.checkpointWithChangedPhysical()
        var refused = false
        do throws(RuntimeFailure) {
            _ = try context.session.restart(forged, codec: NativeRuntimeCheckpointCodec())
        } catch {
            try require(error.code == .invalidContributor && error.contributor == context.definition.schemaID)
            refused = true
        }
        try require(refused && (try context.checkpoint()) == saved)
        let changed = try SensorPipelineProbeContext(noiseHalfWidth: 0.06)
        defer { _ = changed.session.shutdown() }
        let changedPrefix = try changed.checkpoint()
        refused = false
        do throws(RuntimeFailure) {
            _ = try changed.session.restart(saved, codec: NativeRuntimeCheckpointCodec())
        } catch {
            try require(error.code == .invalidContributor && error.contributor == changed.definition.schemaID)
            refused = true
        }
        try require(refused && (try changed.checkpoint()) == changedPrefix)
        try verifySensorReadRefusal(context)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifySensorReadRefusal(_ context: SensorPipelineProbeContext) throws {
        let request = try SensorBatchReadRequest(schema: context.definition.schemaID, version: 1,
            world: "foreign-world", model: context.fixture.model.stamp, after: 0, maximumRows: 32, maximumScalars: 32)
        var refused = false
        do throws(SensorPipelineFailure) {
            try context.session.readBatch(request) { _ throws(SensorPipelineFailure) in }
        } catch {
            guard case .incompatibleSchema = error else { throw FoundationVerificationError.analyticCheckFailed }
            refused = true
        }
        try require(refused)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifySensorReadyQueuePolicies() throws {
        try verifySensorQueueRefusal()
        try verifySensorQueueOverrun()
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifySensorQueueRefusal() throws {
        let context = try SensorPipelineProbeContext(readyRows: 5)
        defer { _ = context.session.shutdown() }
        try context.step(); try context.step(); try context.step()
        let prefix = try context.checkpoint()
        var refused = false
        do throws(IntegrationFailure) { try context.step() }
        catch {
            try require(error.cause.code == .capacityExceeded)
            refused = true
        }
        try require(refused && (try context.checkpoint()) == prefix)
        try require(try context.batch().records.count == 5)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifySensorQueueOverrun() throws {
        let context = try SensorPipelineProbeContext(readyRows: 5, overflow: .retainLatestWithReportedOverrun)
        defer { _ = context.session.shutdown() }
        try context.step(); try context.step(); try context.step(); try context.step()
        var refused = false
        do throws(SensorPipelineFailure) { _ = try context.batch() }
        catch {
            guard case .overrun(let floor) = error, floor == 5 else { throw FoundationVerificationError.analyticCheckFailed }
            refused = true
        }
        let batch = try context.batch(after: 5)
        try require(refused && batch.records.count == 5 && batch.retainedAfter == 5 && batch.lastReadySequence == 10)
        try require(batch.records[0].tick == 2 && batch.records[0].readySequence == 6)
        let cold = try SensorPipelineProbeContext(readyRows: 5, overflow: .retainLatestWithReportedOverrun)
        defer { _ = cold.session.shutdown() }
        let saved = try context.checkpoint()
        _ = try cold.session.restart(saved, codec: NativeRuntimeCheckpointCodec())
        try require(try cold.checkpoint() == saved)
        try require(try cold.batch(after: 5).lastReadySequence == 10)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifySensorLeaseLifetime() throws {
        let context = try SensorPipelineProbeContext()
        defer { _ = context.session.shutdown() }
        try context.step(); try context.step(); try context.step()
        let recorder = SensorPipelineProbeContext.BatchRecorder()
        let request = try SensorBatchReadRequest(schema: context.definition.schemaID, version: 1,
            world: context.definition.world, model: context.fixture.model.stamp, after: 0, maximumRows: 5, maximumScalars: 5)
        let pipeline: any SensorPipelineOperating = context.session
        try pipeline.readBatch(request) { lease throws(SensorPipelineFailure) in
            recorder.retain(lease)
            try lease.read { batch throws(SensorPipelineFailure) in recorder.record(batch) }
        }
        guard let lease = recorder.lease(), let batch = recorder.batch() else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        var refused = false
        do throws(SensorPipelineFailure) {
            try lease.read { _ throws(SensorPipelineFailure) in }
        } catch {
            guard case .invalidLease = error else { throw FoundationVerificationError.analyticCheckFailed }
            refused = true
        }
        try require(refused && batch.records.count == 5)
        _ = context.session.shutdown()
        try require(batch.records[0].source.physical.q == [0.265625])
        refused = false
        do throws(SensorPipelineFailure) {
            try pipeline.readBatch(request) { _ throws(SensorPipelineFailure) in }
        } catch {
            guard case .closed = error else { throw FoundationVerificationError.analyticCheckFailed }
            refused = true
        }
        try require(refused)
    }
}
