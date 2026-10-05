import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SensorProcessingTests {
    @Test func originalEncoderAndMountedIMU() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let definition = try SensorPipelineFixtures.definition(channels: [SensorPipelineFixtures.channel(), SensorPipelineFixtures.imu(quantity: .specificForce, axis: 0), SensorPipelineFixtures.imu(quantity: .angularVelocity, axis: 2)], emitInitial: true)
        let session = try SensorPipelineFixtures.session(definition: definition); defer { session.shutdown() }
        let batch = try SensorBatchCapture().capture(session)
        #expect(batch.records.count == 3)
        let values = batch.records.sorted { $0.channelIndex < $1.channelIndex }
        #expect(values[0].value == 0)
        #expect(abs(values[1].value! - 2) < 1e-12)
        #expect(abs(values[2].value! - 2) < 1e-12)
        #expect(values.allSatisfy { $0.source.physical.acceleration == [2] && $0.source.acceptedSequence == 0 })
        try batch.requireCompatible(schema: definition.schemaID, version: 1, channelIDs: ["position", "specific", "gyro"], dimensions: [.angle, .acceleration, PhysicalDimension(time: -1, angle: 1)])
    }
    @Test func processingOrderAndTieToEven() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let settings = try SensorProcessing(bias: 1, quantizationStep: 0.25, saturationLower: -2, saturationUpper: 2)
        let session = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(channels: [SensorPipelineFixtures.channel(quantity: .velocity, processing: settings)])); defer { session.shutdown() }
        _ = try SensorPipelineFixtures.advance(session, time: 0.125)
        let row = try SensorBatchCapture().capture(session).records[0]
        #expect(row.rawValue == 2.25 && row.value == 2 && row.saturated)
        let ties = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(channels: [SensorPipelineFixtures.channel(processing: SensorProcessing(quantizationStep: 1))])); defer { ties.shutdown() }
        _ = try SensorPipelineFixtures.advance(ties, time: 0.125, q: 1.5); _ = try SensorPipelineFixtures.advance(ties, time: 0.25, q: 2.5)
        #expect(try SensorBatchCapture().capture(ties).records.map { $0.value! } == [2, 2])
    }
    @Test func fixedDrawOracleAndDropoutAssociation() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let settings = try SensorProcessing(bias: 0.1, noiseHalfWidth: 0.05)
        let channels = try [SensorPipelineFixtures.channel(processing: settings), SensorPipelineFixtures.channel(id: "drop", key: 12, processing: SensorProcessing(dropoutProbability: 1))]
        let session = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(channels: channels)); defer { session.shutdown() }
        for i in 1...3 { _ = try SensorPipelineFixtures.advance(session, time: Double(i) * 0.125) }
        let batch = try SensorBatchCapture().capture(session)
        let world = RuntimeRandomState.worldSeed(rootSeed: 123, index: 0)
        var original = RuntimeRandomState(seed: RuntimeRandomState.worldSeed(rootSeed: world, index: 11))
        for row in batch.records where row.channelIndex == 0 {
            _ = try original.next()
            let unit = (Double(try original.next() >> 40) + 0.5) / 16_777_216
            #expect(row.value?.bitPattern == (row.rawValue + 0.1 + (2*unit - 1)*0.05).bitPattern)
        }
        #expect(batch.records.filter { $0.channelIndex == 1 }.allSatisfy { $0.isDropout && $0.value == nil && !$0.saturated })
        #expect(session.snapshot().checkpoint.random.draws == 0)
    }
    @Test func boundedUniformMoments() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let channel = try SensorPipelineFixtures.channel(processing: SensorProcessing(noiseHalfWidth: 1))
        let session = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(channels: [channel], sampling: .previousAcceptedHold)); defer { session.shutdown() }
        _ = try SensorPipelineFixtures.advance(session, time: 64, q: 0)
        let contributor = session.snapshot().checkpoint.contributors.first { $0.id == session.definition.schemaID }!
        let capacity = try SensorPipelineFixtures.capacity()
        #expect(contributor.bytes.count * 8 <= capacity.maximumValidationScratchBytes)
        print("Sensor statistics contributor bytes: \(contributor.bytes.count); caller scratch bytes: \(capacity.maximumValidationScratchBytes)")
        let values = try SensorBatchCapture().capture(session).records.map { $0.value! }
        #expect(values.count == 512 && values.allSatisfy { abs($0) < 1 })
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1-mean)*($1-mean) } / Double(values.count)
        // Fixed seeded 512-sample evidence, with conservative bounded-uniform statistical thresholds.
        #expect(abs(mean) < 0.1)
        #expect(abs(variance - (1 - 1 / 281_474_976_710_656.0)/3) < 0.08)
    }
    @Test(arguments: [Double.nan, Double.infinity, -1.0]) func invalidNoise(_ value: Double) {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        #expect(throws: SensorPipelineFailure.self) { try SensorProcessing(noiseHalfWidth: value) }
    }
    @Test func invalidSettingsAndUnsupportedSelectors() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        #expect(throws: SensorPipelineFailure.self) { try SensorProcessing(quantizationStep: 0) }
        #expect(throws: SensorPipelineFailure.self) { try SensorProcessing(saturationLower: 2, saturationUpper: 1) }
        #expect(throws: SensorPipelineFailure.self) { try SensorProcessing(delaySeconds: -1) }
        #expect(throws: SensorPipelineFailure.self) { try SensorProcessing(dropoutProbability: 1.1) }
        let channel = try SensorChannel(id: "unsupported", streamKey: 1, source: .wrench, dimension: .force, processing: SensorProcessing())
        do { _ = try SensorPipelineFixtures.definition(channels: [channel]); Issue.record("Unsupported original adapter succeeded.") }
        catch let error as SensorPipelineFailure { if case .unsupportedDomain = error {} else { Issue.record("Wrong typed failure.") } }
    }
    @Test(arguments: [SensorChannel.Source.range, .trigger, .tactile]) func unsupportedRawAdapters(_ source: SensorChannel.Source) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let channel = try SensorChannel(id: "unsupported", streamKey: 1, source: source, dimension: .dimensionless, processing: SensorProcessing())
        do { _ = try SensorPipelineFixtures.definition(channels: [channel]); Issue.record("Unqualified raw adapter succeeded.") }
        catch let error as SensorPipelineFailure { if case .unsupportedDomain = error {} else { Issue.record("Wrong raw adapter refusal.") } }
    }
}
