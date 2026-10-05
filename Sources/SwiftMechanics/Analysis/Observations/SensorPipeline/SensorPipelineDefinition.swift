public final class SensorPipelineDefinition: Sendable {
    public enum Sampling: UInt64, Sendable { case endpointOnly, previousAcceptedHold, linearObservationComponents }
    public enum ReadyOverflow: UInt64, Sendable { case refuseOverflow, retainLatestWithReportedOverrun }
    public let schemaID: String
    public let version: UInt64
    public let world: String
    public let rootSeed: UInt64
    public let worldKey: UInt64
    public let initialTimeSeconds: Double
    public let originSeconds: Double
    public let periodSeconds: Double
    public let emitInitial: Bool
    public let sampling: Sampling
    public let readyOverflow: ReadyOverflow
    public let channels: [SensorChannel]
    public let bounds: SensorPipelineBounds
    public let rawPolicy: ObservationPolicy
    public let eventContributorIDs: [String]
    public let schema: RuntimeContributorSchema
    internal let canonical: [UInt8]

    public init(schemaID: String, version: UInt64 = 1, world: String, rootSeed: UInt64, worldKey: UInt64,
                initialTimeSeconds: Double, originSeconds: Double, periodSeconds: Double, emitInitial: Bool,
                sampling: Sampling, readyOverflow: ReadyOverflow, channels: [SensorChannel],
                bounds: SensorPipelineBounds, rawPolicy: ObservationPolicy, eventContributorIDs: [String] = []) throws(SensorPipelineFailure) {
        guard !schemaID.isEmpty, version == 1, !world.isEmpty, !channels.isEmpty, channels.count <= bounds.maximumChannels,
              initialTimeSeconds.isFinite, originSeconds.isFinite, originSeconds >= initialTimeSeconds,
              periodSeconds.isFinite, periodSeconds > 0, (!emitInitial || originSeconds == initialTimeSeconds) else { throw .invalidDefinition }
        var ids: Set<String> = [], keys: Set<UInt64> = []
        for channel in channels {
            guard ids.insert(channel.id).inserted, keys.insert(channel.streamKey).inserted,
                  channel.processing.delaySeconds <= bounds.maximumDelaySeconds else { throw .invalidDefinition }
        }
        guard Set(eventContributorIDs).count == eventContributorIDs.count, !eventContributorIDs.contains(schemaID) else { throw .invalidDefinition }
        self.schemaID = schemaID; self.version = version; self.world = world; self.rootSeed = rootSeed; self.worldKey = worldKey
        self.initialTimeSeconds = initialTimeSeconds; self.originSeconds = originSeconds; self.periodSeconds = periodSeconds
        self.emitInitial = emitInitial; self.sampling = sampling; self.readyOverflow = readyOverflow; self.channels = channels
        self.bounds = bounds; self.rawPolicy = rawPolicy; self.eventContributorIDs = eventContributorIDs
        do { schema = try RuntimeContributorSchema(id: schemaID, category: .observation, version: version, maximumBytes: bounds.maximumContributorBytes) }
        catch { throw .runtime(error) }
        canonical = try Self.encode(schemaID: schemaID, version: version, world: world, rootSeed: rootSeed, worldKey: worldKey,
            initial: initialTimeSeconds, origin: originSeconds, period: periodSeconds, emitInitial: emitInitial,
            sampling: sampling, overflow: readyOverflow, channels: channels, bounds: bounds, policy: rawPolicy, events: eventContributorIDs)
    }
    public func time(at tick: UInt64) throws(SensorPipelineFailure) -> Double {
        guard tick <= bounds.maximumTick else { throw .capacityExceeded }
        let value = originSeconds + Double(tick) * periodSeconds
        guard value.isFinite, tick == 0 || value > originSeconds + Double(tick-1) * periodSeconds else { throw .invalidDefinition }
        return value
    }
    internal var firstTick: UInt64 { originSeconds == initialTimeSeconds && !emitInitial ? 1 : 0 }
    internal func uniform(channel: Int, draw: UInt64) -> Double {
        let worldSeed = RuntimeRandomState.worldSeed(rootSeed: rootSeed, index: worldKey)
        let seed = RuntimeRandomState.worldSeed(rootSeed: worldSeed, index: channels[channel].streamKey)
        let value = RuntimeRandomState.worldSeed(rootSeed: seed, index: draw)
        return (Double(value >> 40) + 0.5) / 16_777_216
    }
    @inline(never)
    private static func encode(schemaID: String, version: UInt64, world: String, rootSeed: UInt64, worldKey: UInt64,
                               initial: Double, origin: Double, period: Double, emitInitial: Bool, sampling: Sampling,
                               overflow: ReadyOverflow, channels: [SensorChannel], bounds: SensorPipelineBounds,
                               policy: ObservationPolicy, events: [String]) throws(SensorPipelineFailure) -> [UInt8] {
        var out = try SensorByteBuffer(maximum: bounds.maximumMetadataBytes)
        try out.append(schemaID); try out.append(version); try out.append(world); try out.append(rootSeed); try out.append(worldKey)
        try out.append(initial); try out.append(origin); try out.append(period); try out.append(UInt64(emitInitial ? 1 : 0))
        try out.append(sampling.rawValue); try out.append(overflow.rawValue)
        for value in [bounds.maximumChannels, bounds.maximumMetadataBytes, bounds.maximumTicksPerStep, bounds.maximumPendingRows,
                      bounds.maximumReadyRows, bounds.maximumBatchRows, bounds.maximumContributorBytes] { try out.append(value) }
        try out.append(bounds.maximumTick); try out.append(bounds.maximumDraws); try out.append(bounds.maximumDelaySeconds)
        for value in [policy.maximumBodies, policy.maximumCoordinates, policy.maximumReactionRows, policy.maximumMetadataBytes] { try out.append(value) }
        try out.append(events.count); for event in events { try out.append(event) }
        try out.append(channels.count)
        for channel in channels {
            try out.append(channel.id); try out.append(channel.streamKey)
            let d = channel.dimension
            for value in [d.length, d.mass, d.time, d.angle, d.electricCurrent, d.temperature, d.amount, d.luminousIntensity] {
                try out.append(UInt64(UInt8(bitPattern: value)))
            }
            switch channel.source {
            case .encoder(let joint, let quantity, let axis):
                guard joint.kind == .joint, axis >= 0 else { throw .invalidDefinition }
                try out.append(UInt64(0)); try out.append(joint.key); try out.append(quantity.rawValue); try out.append(axis)
            case .imu(let mount, let quantity, let axis, let gravity):
                guard (0..<3).contains(axis) else { throw .invalidDefinition }
                try out.append(UInt64(1)); try out.append(mount.sensor.key); try out.append(mount.body.key); try out.append(mount.sensorFrame.key)
                let p = mount.sensorToBody
                for x in [p.rotation.w,p.rotation.x,p.rotation.y,p.rotation.z,p.translation.x,p.translation.y,p.translation.z,gravity.x,gravity.y,gravity.z] { try out.append(x) }
                try out.append(quantity.rawValue); try out.append(axis)
            // FIXME(INCOMPLETE_IMPLEMENTATION): These callable selectors have no pipeline adapter.
            // Definition creation refuses them; actual original source-bound adapter qualification is required before success.
            case .wrench, .range, .trigger, .tactile: throw .unsupportedDomain
            }
            let p = channel.processing
            try out.append(p.bias); try out.append(p.noiseHalfWidth); try out.append(UInt64(p.quantizationStep == nil ? 0 : 1))
            if let step = p.quantizationStep { try out.append(step) }; try out.append(p.quantizationOrigin)
            try out.append(UInt64(p.saturationLower == nil ? 0 : 1))
            if let lower = p.saturationLower, let upper = p.saturationUpper { try out.append(lower); try out.append(upper) }
            try out.append(p.dropoutProbability); try out.append(p.delaySeconds)
        }
        return out.bytes
    }
}
