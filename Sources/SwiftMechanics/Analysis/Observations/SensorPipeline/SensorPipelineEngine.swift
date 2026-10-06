@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class SensorPipelineEngine: Sendable {
    let definition: SensorPipelineDefinition
    let capacity: RuntimeCapacity
    let sources: any ObservationSourcePreparing
    init(definition: SensorPipelineDefinition, capacity: RuntimeCapacity,
         sources: any ObservationSourcePreparing = ReferenceObservationSourcePreparer()) {
        self.definition = definition; self.capacity = capacity; self.sources = sources
    }
    @inline(never)
    func binding(model: CompiledMechanicalModel, physical: KinematicState, sequence: UInt64) throws(SensorPipelineFailure) -> SensorPhysicalSource {
        guard model.tree.bodies.count <= definition.rawPolicy.maximumBodies,
              model.tree.joints.count <= definition.rawPolicy.maximumBodies,
              model.tree.layout.positionCount <= definition.rawPolicy.maximumCoordinates,
              model.tree.layout.velocityCount <= definition.rawPolicy.maximumCoordinates else { throw .capacityExceeded }
        var layout = try SensorByteBuffer(maximum: definition.bounds.maximumMetadataBytes)
        try layout.append(model.tree.worldFrame.key); try layout.append(model.tree.layout.positionCount); try layout.append(model.tree.layout.velocityCount)
        try layout.append(model.tree.bodies.count)
        for body in model.tree.bodies { try layout.append(body.id.key); try layout.append(body.frame.key) }
        try layout.append(model.tree.joints.count)
        for joint in model.tree.joints {
            try layout.append(joint.id.key); try layout.append(joint.parentBody.key); try layout.append(joint.childBody.key)
            try layout.append(joint.parentAnchor.frame.key); try layout.append(joint.childAnchor.frame.key)
        }
        var frames: [SensorFrameBinding] = []; frames.reserveCapacity(definition.channels.count)
        for (i, channel) in definition.channels.enumerated() {
            let binding: SensorFrameBinding
            switch channel.source {
            case .encoder(let id, _, _):
                guard let joint = model.tree.joints.first(where: { $0.id == id }), let range = model.tree.layout.joints.first(where: { $0.joint == id }) else { throw .invalidDefinition }
                let convention: JointEncoderObservation.VelocityConvention
                switch joint.manifold.kind { case .spherical: convention = .bodyAngular; case .sixDOF: convention = .parentLinearAndBodyAngular; default: convention = .orderedAxisRates }
                binding = SensorFrameBinding(channel: i, body: joint.childBody, frame: joint.parentAnchor.frame, convention: convention)
                try layout.append(range.positions.range.lowerBound); try layout.append(range.positions.count)
                try layout.append(range.velocities.range.lowerBound); try layout.append(range.velocities.count)
                try layout.append(UInt64(convention == .bodyAngular ? 1 : (convention == .parentLinearAndBodyAngular ? 2 : 0)))
            case .imu(let mount, _, _, _): binding = SensorFrameBinding(channel: i, body: mount.body, frame: mount.sensorFrame, convention: nil)
            // FIXME(INCOMPLETE_IMPLEMENTATION): No original-source frame adapter exists for these pipeline selectors.
            // They are refused at construction; complete source/frame behavior must be qualified before success.
            case .wrench, .range, .trigger, .tactile: throw .unsupportedDomain
            }
            frames.append(binding); try layout.append(binding.body.key); try layout.append(binding.frame.key)
        }
        do throws(RuntimeFailure) {
            let continuation = try RuntimeContinuationIdentity(build: "sensor-source-v1", backend: "physical-record", precision: "float64")
            let association = try RuntimeContributorState(id: "sensor.source.frames.v1", category: .observation, version: 1, bytes: layout.bytes)
            let checkpoint = try RuntimeCheckpoint(model: model.stamp, continuation: continuation, physical: physical,
                contributors: [association], random: RuntimeRandomState(seed: 0), acceptedSteps: sequence)
            let bytes = try NativeRuntimeCheckpointCodec().encode(checkpoint, capacity: capacity)
            return SensorPhysicalSource(model: model.stamp, physical: physical, sequence: sequence, frames: frames, encoded: bytes)
        } catch { throw .runtime(error) }
    }
    @inline(never)
    func decodeBinding(_ bytes: [UInt8], model: CompiledMechanicalModel) throws(SensorPipelineFailure) -> SensorPhysicalSource {
        let checkpoint: RuntimeCheckpoint
        do throws(RuntimeFailure) { checkpoint = try NativeRuntimeCheckpointCodec().decode(bytes, capacity: capacity) }
        catch { throw .runtime(error) }
        guard checkpoint.model == model.stamp, checkpoint.contributors.count == 1,
              checkpoint.contributors[0].id == "sensor.source.frames.v1", checkpoint.contributors[0].category == .observation, checkpoint.contributors[0].version == 1,
              checkpoint.continuation.build == "sensor-source-v1", checkpoint.continuation.backend == "physical-record",
              checkpoint.continuation.precision == "float64", checkpoint.random == RuntimeRandomState(seed: 0) else { throw .staleSource }
        do { _ = try model.makeState(checkpoint.physical) } catch { throw .staleSource }
        let original = try binding(model: model, physical: checkpoint.physical, sequence: checkpoint.acceptedSteps)
        guard original.encoded == bytes else { throw .corruptState }
        return original
    }
    @inline(never)
    func raw(model: CompiledMechanicalModel, binding: SensorPhysicalSource, work: inout NumericalWork) throws(SensorPipelineFailure) -> [Double] {
        let compiled: CompiledKinematicState
        do { compiled = try model.makeState(binding.physical) } catch { throw .staleSource }
        let source: ObservationSource
        let before = work
        do throws(ObservationError) { source = try sources.prepare(model: model, state: compiled, solved: nil, policy: definition.rawPolicy, work: &work) }
        catch { throw .observation(error, operations: work.operations) }
        guard work.budget == before.budget, work.operations > before.operations,
              work.iterations >= before.iterations, work.peakScalarStorage >= before.peakScalarStorage,
              source.accelerationAuthority == .suppliedState, source.model.stamp == model.stamp, source.state.stamp == model.stamp,
              try self.binding(model: model, physical: source.state.state, sequence: binding.acceptedSequence).encoded == binding.encoded else { throw .staleSource }
        // An injected source must agree with the original physical observer, not merely its header.
        var validationWork = NumericalWork(budget: definition.bounds.rawBudget)
        let original: ObservationSource
        do throws(ObservationError) { original = try ReferenceObservationSourcePreparer().prepare(model: model, state: compiled,
            solved: nil, policy: definition.rawPolicy, work: &validationWork) }
        catch { throw .observation(error, operations: validationWork.operations) }
        var values: [Double] = []; values.reserveCapacity(definition.channels.count)
        for channel in definition.channels {
            let actual = try raw(channel, source: source, work: &work)
            let expected = try raw(channel, source: original, work: &validationWork)
            guard actual.bitPattern == expected.bitPattern else { throw .staleSource }
            values.append(actual)
        }
        do { try work.absorb(validationWork, reservedStorage: values.count) }
        catch { throw .observation(.numerical(error), operations: work.operations) }
        return values
    }
    private func raw(_ channel: SensorChannel, source: ObservationSource, work: inout NumericalWork) throws(SensorPipelineFailure) -> Double {
        switch channel.source {
        case .encoder(let joint, let quantity, let axis):
            let sample: JointEncoderObservation
            do throws(ObservationError) { sample = try ReferenceKinematicObserver().encoder(source: source, joint: joint, policy: definition.rawPolicy, work: &work) }
            catch { throw .observation(error, operations: work.operations) }
            if definition.sampling == .linearObservationComponents, sample.velocityConvention != .orderedAxisRates { throw .unsupportedDomain }
            let values: [Double], units: [PhysicalDimension]
            switch quantity {
            case .position: values = sample.positions; units = sample.positionUnits
            case .coordinateRate: values = sample.coordinateRates; units = sample.coordinateRateUnits
            case .velocity: values = sample.velocities; units = sample.velocityUnits
            case .acceleration: values = sample.accelerations; units = sample.accelerationUnits
            }
            guard values.indices.contains(axis), units.indices.contains(axis), units[axis] == channel.dimension else { throw .invalidDefinition }
            return values[axis]
        case .imu(let mount, let quantity, let axis, let gravityWorld):
            let field: AffineGravity
            do throws(LoadError) { field = try AffineGravity(frame: source.snapshot.tree.worldFrame, accelerationAtOrigin: gravityWorld) }
            catch { throw .load(error) }
            let sample: IMUObservation
            do throws(ObservationError) {
                let gravity = try ObservationGravity(model: source.model.stamp, timeSeconds: source.state.state.time, field: field)
                sample = try ReferenceRigidIMUObserver().sample(source: source, mount: mount, gravity: gravity, policy: definition.rawPolicy, work: &work)
            } catch { throw .observation(error, operations: work.operations) }
            let vector = quantity == .angularVelocity ? sample.angularVelocitySensor : sample.specificForceSensor
            let dimension = quantity == .angularVelocity ? sample.angularVelocityUnit : sample.specificForceUnit
            guard dimension == channel.dimension, (0..<3).contains(axis) else { throw .invalidDefinition }
            return axis == 0 ? vector.x : (axis == 1 ? vector.y : vector.z)
        // FIXME(INCOMPLETE_IMPLEMENTATION): No source-bound adapter exists for these selectors.
        // Construction also refuses; original raw/reaction adapter and pipeline behavior must be qualified before success.
        case .wrench, .range, .trigger, .tactile: throw .unsupportedDomain
        }
    }
    @inline(never)
    func initial(model: CompiledMechanicalModel, physical: KinematicState) throws(SensorPipelineFailure) -> SensorPipelineState {
        guard physical.time == definition.initialTimeSeconds else { throw .invalidDefinition }
        let source = try binding(model: model, physical: physical, sequence: 0)
        var state = SensorPipelineState(source: source, nextTick: definition.firstTick,
            draws: [UInt64](repeating: 0, count: definition.channels.count), pending: [], ready: [], lastReady: 0, floor: 0)
        var work = NumericalWork(budget: definition.bounds.rawBudget)
        let values = try raw(model: model, binding: source, work: &work)
        if definition.emitInitial { try issue(&state, tick: 0, time: physical.time, before: source, after: nil, beforeValues: values, afterValues: values); state.nextTick = 1 }
        try mature(&state, at: physical.time)
        return state
    }
    @inline(never)
    func advance(_ state: inout SensorPipelineState, model: CompiledMechanicalModel,
                 physical: KinematicState, sequence: UInt64, control: RuntimeStepControl) throws(SensorPipelineFailure) {
        guard physical.time >= state.source.physical.time, state.source.acceptedSequence < UInt64.max,
              sequence == state.source.acceptedSequence + 1 else { throw .staleSource }
        // FIXME(INCOMPLETE_IMPLEMENTATION): There is no original universal event-history callback.
        // Registered event domains are refused until an original typed boundary adapter is admitted and tested.
        guard definition.eventContributorIDs.isEmpty else { throw .unsupportedDomain }
        var tick = state.nextTick, ticks = 0
        while try definition.time(at: tick) <= physical.time {
            guard try definition.time(at: tick) > state.source.physical.time,
                  ticks < definition.bounds.maximumTicksPerStep, tick < definition.bounds.maximumTick else { throw .capacityExceeded }
            if definition.sampling == .endpointOnly { guard try definition.time(at: tick) == physical.time else { throw .unsupportedDomain } }
            tick += 1; ticks += 1
        }
        let after = try binding(model: model, physical: physical, sequence: sequence)
        if ticks > 0 {
            do { try control.beginWorkBlock(units: 1) } catch { throw .runtime(error) }
            var work = NumericalWork(budget: definition.bounds.rawBudget)
            let beforeValues = try raw(model: model, binding: state.source, work: &work)
            let afterValues = try raw(model: model, binding: after, work: &work)
            for current in state.nextTick..<tick {
                do { try control.beginWorkBlock(units: 1) } catch { throw .runtime(error) }
                let time = try definition.time(at: current)
                switch definition.sampling {
                case .endpointOnly: try issue(&state, tick: current, time: time, before: after, after: nil, beforeValues: afterValues, afterValues: afterValues)
                case .previousAcceptedHold: try issue(&state, tick: current, time: time, before: state.source, after: nil, beforeValues: beforeValues, afterValues: beforeValues)
                case .linearObservationComponents: try issue(&state, tick: current, time: time, before: state.source, after: after, beforeValues: beforeValues, afterValues: afterValues)
                }
            }
        }
        state.source = after; state.nextTick = tick
        try mature(&state, at: physical.time)
    }
    private func issue(_ state: inout SensorPipelineState, tick: UInt64, time: Double, before: SensorPhysicalSource,
                       after: SensorPhysicalSource?, beforeValues: [Double], afterValues: [Double]) throws(SensorPipelineFailure) {
        guard definition.channels.count <= definition.bounds.maximumPendingRows - state.pending.count else { throw .capacityExceeded }
        for i in definition.channels.indices {
            let channel = definition.channels[i], draw = state.draws[i]
            guard draw <= definition.bounds.maximumDraws, definition.bounds.maximumDraws - draw >= 2 else { throw .capacityExceeded }
            let dropout = definition.uniform(channel: i, draw: draw) < channel.processing.dropoutProbability
            let noise = definition.uniform(channel: i, draw: draw+1)
            let raw = try interpolated(time: time, before: before, after: after, rawBefore: beforeValues[i], rawAfter: afterValues[i])
            let transformed = try channel.processing.apply(raw, noise: noise)
            let deadline = time + channel.processing.delaySeconds
            guard deadline.isFinite else { throw .nonfinite }
            state.pending.append(SensorRecord(channel: i, tick: tick, sampleTime: time, sourceTime: before.physical.time,
                source: before, bracketEnd: after, rawBefore: beforeValues[i], rawAfter: afterValues[i], rawValue: raw,
                value: dropout ? nil : transformed.0, saturated: !dropout && transformed.1, deadline: deadline, deliveryTime: nil, readySequence: 0))
            state.draws[i] += 2
        }
    }
    private func interpolated(time: Double, before: SensorPhysicalSource, after: SensorPhysicalSource?, rawBefore: Double, rawAfter: Double) throws(SensorPipelineFailure) -> Double {
        guard let after else { return rawBefore }
        let span = after.physical.time - before.physical.time
        guard span.isFinite, span > 0, time > before.physical.time, time <= after.physical.time else { throw .unsupportedDomain }
        let fraction = (time - before.physical.time) / span
        let value = rawBefore + fraction * (rawAfter - rawBefore)
        guard value.isFinite else { throw .nonfinite }; return value
    }
    private func ordered(_ a: SensorRecord, _ b: SensorRecord) -> Bool {
        if a.releaseDeadline != b.releaseDeadline { return a.releaseDeadline < b.releaseDeadline }
        if a.sampleTime != b.sampleTime { return a.sampleTime < b.sampleTime }
        let ak = definition.channels[a.channelIndex].streamKey, bk = definition.channels[b.channelIndex].streamKey
        return ak == bk ? a.tick < b.tick : ak < bk
    }
    private func mature(_ state: inout SensorPipelineState, at time: Double) throws(SensorPipelineFailure) {
        state.pending.sort(by: ordered)
        var count = 0
        for row in state.pending {
            guard row.releaseDeadline <= time else { break }
            guard state.lastReady < UInt64.max else { throw .capacityExceeded }
            if state.ready.count == definition.bounds.maximumReadyRows {
                guard definition.readyOverflow == .retainLatestWithReportedOverrun, !state.ready.isEmpty else { throw .capacityExceeded }
                state.floor = state.ready.removeFirst().readySequence
            }
            state.lastReady += 1; state.ready.append(row.delivered(at: time, sequence: state.lastReady)); count += 1
        }
        if count > 0 { state.pending.removeFirst(count) }
    }
    @inline(never)
    func record(_ state: SensorPipelineState) throws(SensorPipelineFailure) -> RuntimeContributorState {
        var out = try SensorByteBuffer(maximum: definition.bounds.maximumContributorBytes)
        try out.append(definition.canonical); try out.append(state.source.encoded); try out.append(state.nextTick)
        try out.append(state.draws.count); for draw in state.draws { try out.append(draw) }
        try out.append(state.lastReady); try out.append(state.floor)
        for rows in [state.pending, state.ready] { try out.append(rows.count); for row in rows { try write(row, to: &out) } }
        do { return try RuntimeContributorState(id: definition.schemaID, category: .observation, version: definition.version, bytes: out.bytes) }
        catch { throw .runtime(error) }
    }
    private func write(_ row: SensorRecord, to out: inout SensorByteBuffer) throws(SensorPipelineFailure) {
        try out.append(row.channelIndex); try out.append(row.tick); try out.append(row.sampleTime); try out.append(row.sourceTime)
        try out.append(row.source.encoded); try out.append(UInt64(row.bracketEnd == nil ? 0 : 1))
        if let end = row.bracketEnd { try out.append(end.encoded) }
        try out.append(row.rawBefore); try out.append(row.rawAfter); try out.append(row.rawValue)
        try out.append(UInt64(row.value == nil ? 0 : 1)); if let value = row.value { try out.append(value) }
        try out.append(UInt64(row.saturated ? 1 : 0)); try out.append(row.releaseDeadline)
        try out.append(UInt64(row.deliveryTime == nil ? 0 : 1)); if let time = row.deliveryTime { try out.append(time) }
        try out.append(row.readySequence)
    }
    @inline(never)
    func decode(_ record: RuntimeContributorState, model: CompiledMechanicalModel,
                budget: RuntimeValidationBudget? = nil) throws(SensorPipelineFailure) -> SensorDecodedState {
        guard record.id == definition.schemaID, record.category == .observation, record.version == definition.version else { throw .incompatibleSchema }
        let reservedScratch = record.bytes.count.multipliedReportingOverflow(by: 8)
        guard !reservedScratch.overflow else { throw .capacityExceeded }
        if let budget { guard reservedScratch.partialValue <= budget.scratchBytes, record.bytes.count <= budget.workUnits else { throw .capacityExceeded } }
        var input = try SensorByteBuffer(maximum: definition.bounds.maximumContributorBytes, bytes: record.bytes)
        guard try input.payload(maximum: definition.bounds.maximumMetadataBytes) == definition.canonical else { throw .incompatibleSchema }
        let source = try decodeBinding(input.payload(maximum: capacity.maximumCheckpointBytes), model: model)
        let next = try input.integer(), count = try input.count(maximum: definition.channels.count)
        guard count == definition.channels.count, next >= definition.firstTick, next <= definition.bounds.maximumTick else { throw .corruptState }
        var draws: [UInt64] = []
        let issued = next - definition.firstTick
        let (expectedDraws, overflow) = issued.multipliedReportingOverflow(by: 2)
        guard !overflow, expectedDraws <= definition.bounds.maximumDraws else { throw .capacityExceeded }
        for _ in 0..<count { let draw = try input.integer(); guard draw == expectedDraws else { throw .corruptState }; draws.append(draw) }
        let last = try input.integer(), floor = try input.integer()
        guard floor <= last, try definition.time(at: next) > source.physical.time else { throw .corruptState }
        if next != definition.firstTick { guard try definition.time(at: next-1) <= source.physical.time else { throw .corruptState } }
        let (totalIssued, issuedOverflow) = issued.multipliedReportingOverflow(by: UInt64(definition.channels.count))
        guard !issuedOverflow, last <= totalIssued else { throw .corruptState }
        var groups: [[SensorRecord]] = []
        var retainedKeys: Set<String> = []
        var work = NumericalWork(budget: definition.bounds.rawBudget)
        _ = try raw(model: model, binding: source, work: &work)
        for group in 0..<2 {
            let maximum = group == 0 ? definition.bounds.maximumPendingRows : definition.bounds.maximumReadyRows
            let rows = try input.count(maximum: maximum)
            guard rows <= (input.bytes.count - input.cursor) / 104 else { throw .corruptState }
            var records: [SensorRecord] = []; records.reserveCapacity(rows)
            for _ in 0..<rows {
                let row = try read(from: &input, model: model)
                guard retainedKeys.insert(String(row.channelIndex) + ":" + String(row.tick)).inserted else { throw .corruptState }
                try validate(row, stateSource: source, next: next, model: model, work: &work)
                if group == 0 { guard row.deliveryTime == nil, row.readySequence == 0, row.releaseDeadline > source.physical.time else { throw .corruptState } }
                else { guard let delivery = row.deliveryTime, delivery >= row.releaseDeadline, delivery <= source.physical.time,
                             row.readySequence > floor, row.readySequence <= last else { throw .corruptState } }
                if let previous = records.last {
                    if group == 0 { guard ordered(previous, row) else { throw .corruptState } }
                    else { guard previous.readySequence < UInt64.max, row.readySequence == previous.readySequence + 1 else { throw .corruptState } }
                }
                records.append(row)
            }
            groups.append(records)
        }
        guard input.cursor == input.bytes.count,
              UInt64(groups[0].count) == totalIssued - last, UInt64(groups[1].count) == last - floor,
              groups[1].first?.readySequence == (groups[1].isEmpty ? nil : floor + 1) else { throw .corruptState }
        if let budget {
            let (total, overflow) = record.bytes.count.addingReportingOverflow(work.operations)
            let (scratch, storageOverflow) = work.peakScalarStorage.multipliedReportingOverflow(by: 8)
            guard !overflow, total <= budget.workUnits, !storageOverflow, scratch <= budget.scratchBytes - reservedScratch.partialValue else { throw .capacityExceeded }
        }
        let state = SensorPipelineState(source: source, nextTick: next, draws: draws, pending: groups[0], ready: groups[1], lastReady: last, floor: floor)
        guard try self.record(state).bytes == record.bytes else { throw .corruptState }
        let total = record.bytes.count.addingReportingOverflow(work.operations)
        let storage = work.peakScalarStorage.multipliedReportingOverflow(by: 8)
        let scratch = reservedScratch.partialValue.addingReportingOverflow(storage.partialValue)
        guard !total.overflow, !storage.overflow, !scratch.overflow else { throw .capacityExceeded }
        let evidence: RuntimeValidationEvidence
        do { evidence = try RuntimeValidationEvidence(workUnitsUsed: total.partialValue, scratchBytesUsed: scratch.partialValue) }
        catch { throw .runtime(error) }
        return SensorDecodedState(state: state, evidence: evidence)
    }
    private func read(from input: inout SensorByteBuffer, model: CompiledMechanicalModel) throws(SensorPipelineFailure) -> SensorRecord {
        let channel = try input.count(maximum: definition.channels.count - 1), tick = try input.integer()
        let time = try input.scalar(), sourceTime = try input.scalar()
        let source = try decodeBinding(input.payload(maximum: capacity.maximumCheckpointBytes), model: model)
        let end = try input.flag() ? decodeBinding(input.payload(maximum: capacity.maximumCheckpointBytes), model: model) : nil
        let before = try input.scalar(), after = try input.scalar(), raw = try input.scalar()
        let value = try input.flag() ? input.scalar() : nil
        let saturated = try input.flag(), deadline = try input.scalar()
        let delivery = try input.flag() ? input.scalar() : nil, sequence = try input.integer()
        return SensorRecord(channel: channel, tick: tick, sampleTime: time, sourceTime: sourceTime, source: source,
            bracketEnd: end, rawBefore: before, rawAfter: after, rawValue: raw, value: value, saturated: saturated,
            deadline: deadline, deliveryTime: delivery, readySequence: sequence)
    }
    private func validate(_ row: SensorRecord, stateSource: SensorPhysicalSource, next: UInt64,
                          model: CompiledMechanicalModel, work: inout NumericalWork) throws(SensorPipelineFailure) {
        guard row.tick >= definition.firstTick, row.tick < next, row.sampleTime == (try definition.time(at: row.tick)),
              row.sourceTime.bitPattern == row.source.physical.time.bitPattern,
              row.source.acceptedSequence <= stateSource.acceptedSequence, row.source.physical.time <= stateSource.physical.time,
              row.sampleTime <= stateSource.physical.time else { throw .staleSource }
        let before = try raw(model: model, binding: row.source, work: &work)[row.channelIndex]
        var after = before
        if let end = row.bracketEnd {
            guard definition.sampling == .linearObservationComponents, end.acceptedSequence <= stateSource.acceptedSequence,
                  row.source.acceptedSequence < UInt64.max, end.acceptedSequence == row.source.acceptedSequence + 1, end.physical.time <= stateSource.physical.time else { throw .staleSource }
            after = try raw(model: model, binding: end, work: &work)[row.channelIndex]
        } else if definition.sampling == .endpointOnly { guard row.sourceTime == row.sampleTime else { throw .staleSource } }
        else if definition.sampling == .linearObservationComponents { guard row.tick == 0, definition.emitInitial else { throw .staleSource } }
        guard row.sourceTime <= row.sampleTime, before.bitPattern == row.rawBefore.bitPattern, after.bitPattern == row.rawAfter.bitPattern else { throw .staleSource }
        let value = try interpolated(time: row.sampleTime, before: row.source, after: row.bracketEnd, rawBefore: before, rawAfter: after)
        guard value.bitPattern == row.rawValue.bitPattern else { throw .staleSource }
        let channel = definition.channels[row.channelIndex], draw = (row.tick - definition.firstTick) * 2
        let dropout = definition.uniform(channel: row.channelIndex, draw: draw) < channel.processing.dropoutProbability
        let processed = try channel.processing.apply(value, noise: definition.uniform(channel: row.channelIndex, draw: draw+1))
        guard row.releaseDeadline.bitPattern == (row.sampleTime + channel.processing.delaySeconds).bitPattern,
              row.isDropout == dropout, row.saturated == (!dropout && processed.1),
              dropout || row.value?.bitPattern == processed.0.bitPattern else { throw .corruptState }
    }
}
