public struct ReferenceExternalCommandScheduler: ExternalCommandScheduling, Sendable {
    public init() {}

    public func bind(binding: ActuatorBinding, model: CompiledMechanicalModel, producer: String,
                     configurationRevision: UInt64, mode: DriveMode, clock: ControlClock,
                     delaySeconds: Double, maximumAgeSeconds: Double, maximumGapSeconds: Double,
                     interpolation: ExternalCommandInterpolation, actuationWork: inout ActuationWork,
                     work: inout ExternalCommandWork) throws(ExternalCommandError) -> ExternalCommandCheckpoint {
        try work.charge(1); try work.metadata(producer)
        guard !producer.isEmpty, configurationRevision > 0 else { throw .invalidIdentity }
        guard binding.authority == .dynamicState else { throw .incompatibleBinding }
        do { try binding.validate(model: model, work: &actuationWork) }
        catch { throw .actuation(error) }
        guard delaySeconds.isFinite, delaySeconds >= 0, maximumAgeSeconds.isFinite, maximumAgeSeconds >= 0,
              maximumGapSeconds.isFinite, maximumGapSeconds >= 0 else { throw .invalidPolicy }
        let dimension: PhysicalDimension
        switch mode {
        case .position: dimension = binding.coordinate == .translation ? .length : .angle
        case .velocity: dimension = binding.coordinate == .translation
            ? PhysicalDimension(length: 1, time: -1) : PhysicalDimension(time: -1, angle: 1)
        case .effort: dimension = binding.coordinate == .translation ? .force : .energy
        }
        let unit: UnitDefinition
        do { unit = try UnitDefinition(symbol: "SI", dimension: dimension, scale: 1, offset: 0) }
        catch { throw .core(error) }
        do { _ = try clock.time(at: 0) } catch { throw .control(error) }
        try work.charge(1)
        let stream = ExternalCommandStream(binding: binding, producer: producer,
            configurationRevision: configurationRevision, mode: mode, clock: clock, delaySeconds: delaySeconds,
            maximumAgeSeconds: maximumAgeSeconds, maximumGapSeconds: maximumGapSeconds,
            interpolation: interpolation, siUnit: unit)
        return ExternalCommandCheckpoint(stream: stream, packets: [], valuesInSI: [],
                                         lastTick: nil, lastTargetTimeSeconds: nil)
    }

    public func append(_ packets: [ExternalCommandPacket], to checkpoint: ExternalCommandCheckpoint,
                       converter: any UnitConverting, work: inout ExternalCommandWork)
        throws(ExternalCommandError) -> ExternalCommandCheckpoint {
        try validate(checkpoint, work: &work)
        guard packets.count <= work.policy.maximumBatch else {
            throw .capacity(resource: "batch", limit: work.policy.maximumBatch)
        }
        let count = try ExternalCommandWork.sum(checkpoint.packets.count, packets.count)
        guard count <= work.policy.maximumPackets else {
            throw .capacity(resource: "packets", limit: work.policy.maximumPackets)
        }
        if packets.isEmpty { try work.charge(0); return checkpoint }
        try reserve(count, work: &work)
        var retained: [ExternalCommandPacket] = []; retained.reserveCapacity(count)
        var converted: [Double] = []; converted.reserveCapacity(count)
        retained.append(contentsOf: checkpoint.packets); converted.append(contentsOf: checkpoint.valuesInSI)
        var previous = checkpoint.packets.last
        for packet in packets {
            try admit(packet, stream: checkpoint.stream, previous: previous, work: &work)
            if let selected = checkpoint.lastTargetTimeSeconds, packet.sourceTimeSeconds <= selected {
                throw .stalePacket
            }
            let value: Double
            do { value = try converter.convert(packet.value, from: packet.unit, to: checkpoint.stream.siUnit) }
            catch { throw .core(error) }
            guard value.isFinite else { throw .nonfiniteResult }
            try work.charge(1)
            retained.append(packet); converted.append(value); previous = packet
        }
        try work.charge(0)
        return ExternalCommandCheckpoint(stream: checkpoint.stream, packets: retained, valuesInSI: converted,
            lastTick: checkpoint.lastTick, lastTargetTimeSeconds: checkpoint.lastTargetTimeSeconds)
    }

    public func select(tick: UInt64, from checkpoint: ExternalCommandCheckpoint, work: inout ExternalCommandWork)
        throws(ExternalCommandError) -> ExternalCommandSelection {
        try validate(checkpoint, work: &work)
        if let previous = checkpoint.lastTick, tick <= previous { throw .staleTick }
        let application = try clockTime(checkpoint.stream.clock, tick: tick)
        let target = application - checkpoint.stream.delaySeconds
        guard target.isFinite else { throw .nonfiniteResult }
        guard target >= checkpoint.stream.clock.epochSeconds else { throw .synchronizationUnavailable }
        if let previous = checkpoint.lastTargetTimeSeconds, target <= previous { throw .invalidTime }
        var left: Int?, right: Int?
        for index in checkpoint.packets.indices {
            try work.charge(1)
            let packet = checkpoint.packets[index]
            if packet.arrivalTimeSeconds > application { break }
            if packet.sourceTimeSeconds <= target { left = index }
            else { right = index; break }
        }
        guard let first = left else { throw .synchronizationUnavailable }
        let firstPacket = checkpoint.packets[first], firstValue = checkpoint.valuesInSI[first]
        let age = target - firstPacket.sourceTimeSeconds
        guard age.isFinite, age >= 0 else { throw .invalidTime }
        let applicationAge = application - firstPacket.sourceTimeSeconds
        guard applicationAge.isFinite, applicationAge >= 0 else { throw .invalidTime }
        guard applicationAge <= checkpoint.stream.maximumAgeSeconds else { throw .ageExceeded }
        var second: Int?, secondWeight = 0.0
        switch checkpoint.stream.interpolation {
        case .exact:
            guard firstPacket.sourceTimeSeconds == target else { throw .synchronizationUnavailable }
        case .zeroOrderHold: break
        case .linear:
            if firstPacket.sourceTimeSeconds != target {
                guard let following = right else { throw .synchronizationUnavailable }
                let gap = checkpoint.packets[following].sourceTimeSeconds - firstPacket.sourceTimeSeconds
                guard gap.isFinite, gap > 0 else { throw .invalidTime }
                guard gap <= checkpoint.stream.maximumGapSeconds else { throw .gapExceeded }
                secondWeight = age / gap
                guard secondWeight.isFinite, secondWeight > 0, secondWeight < 1 else { throw .invalidTime }
                second = following
            }
        }
        let firstWeight = 1 - secondWeight
        let value: Double
        if let second { value = firstWeight * firstValue + secondWeight * checkpoint.valuesInSI[second] }
        else { value = firstValue }
        guard value.isFinite else { throw .nonfiniteResult }
        let command: DriveCommand
        do { command = try DriveCommand(mode: checkpoint.stream.mode, value: value) }
        catch { throw .actuation(error) }
        try work.charge(5)
        let next = ExternalCommandCheckpoint(stream: checkpoint.stream, packets: checkpoint.packets,
            valuesInSI: checkpoint.valuesInSI, lastTick: tick, lastTargetTimeSeconds: target)
        return ExternalCommandSelection(command: command, actuator: checkpoint.stream.binding, tick: tick,
            applicationTimeSeconds: application, targetSourceTimeSeconds: target,
            firstPacket: firstPacket, secondPacket: second.map { checkpoint.packets[$0] },
            firstWeight: firstWeight, secondWeight: secondWeight, firstValueInSI: firstValue,
            secondValueInSI: second.map { checkpoint.valuesInSI[$0] }, nextCheckpoint: next)
    }

    public func drive(tick: UInt64, from checkpoint: ExternalCommandCheckpoint, law: ScalarServo,
                      state: ActuatorState, sample: ActuatorSample, evaluator: any DriveEvaluating,
                      energyTolerance: NumericalTolerance, actuationWork: inout ActuationWork,
                      numericalWork: inout NumericalWork, work: inout ExternalCommandWork)
        throws(ExternalCommandError) -> ExternalDriveStep {
        let selected = try select(tick: tick, from: checkpoint, work: &work)
        try work.charge(5)
        guard law.binding == selected.actuator, state.binding == selected.actuator,
              sample.binding == selected.actuator, sample.time == selected.applicationTimeSeconds,
              state.mode == selected.command.mode else { throw .incompatibleBinding }
        let end: Double
        do { end = try checkpoint.stream.clock.end(after: tick) } catch { throw .control(error) }
        let dt = end - selected.applicationTimeSeconds
        guard dt.isFinite, dt > 0 else { throw .invalidTime }
        let response: ActuatorResponse
        do {
            response = try evaluator.step(law: law, state: state, sample: sample, command: selected.command,
                dt: dt, energyTolerance: energyTolerance, work: &actuationWork, numerical: &numericalWork)
        } catch { throw .actuation(error) }
        guard response.state.binding == selected.actuator, response.state.time == end else {
            throw .invalidCheckpoint
        }
        try work.charge(0)
        return ExternalDriveStep(selection: selected, actuatorResponse: response, intervalEndTimeSeconds: end)
    }

    public func prune(_ checkpoint: ExternalCommandCheckpoint, work: inout ExternalCommandWork)
        throws(ExternalCommandError) -> ExternalCommandCheckpoint {
        try validate(checkpoint, work: &work)
        guard let selected = checkpoint.lastTargetTimeSeconds else { return checkpoint }
        var first = 0
        for index in checkpoint.packets.indices {
            try work.charge(1)
            if checkpoint.packets[index].sourceTimeSeconds <= selected { first = index } else { break }
        }
        if first == 0 { return checkpoint }
        let count = checkpoint.packets.count - first
        try reserve(count, work: &work)
        let packets = Array(checkpoint.packets[first...]), values = Array(checkpoint.valuesInSI[first...])
        try work.charge(0)
        return ExternalCommandCheckpoint(stream: checkpoint.stream, packets: packets, valuesInSI: values,
            lastTick: checkpoint.lastTick, lastTargetTimeSeconds: checkpoint.lastTargetTimeSeconds)
    }

    public func restore(stream: ExternalCommandStream, packets: [ExternalCommandPacket], lastTick: UInt64?,
                        converter: any UnitConverting, work: inout ExternalCommandWork)
        throws(ExternalCommandError) -> ExternalCommandCheckpoint {
        let empty = ExternalCommandCheckpoint(stream: stream, packets: [], valuesInSI: [],
            lastTick: nil, lastTargetTimeSeconds: nil)
        let parsed = try append(packets, to: empty, converter: converter, work: &work)
        guard let lastTick else { return parsed }
        // Replay the actual selection to reject checkpoints without arrived, admissible source data.
        let restored = try select(tick: lastTick, from: parsed, work: &work)
        return restored.nextCheckpoint
    }

    private func validate(_ checkpoint: ExternalCommandCheckpoint, work: inout ExternalCommandWork)
        throws(ExternalCommandError) {
        try work.charge(1)
        let stream = checkpoint.stream
        try work.metadata(stream.producer); try work.metadata(stream.binding.model.identity)
        try work.metadata(stream.binding.actuator.key); try work.metadata(stream.binding.joint.key)
        try work.metadata(stream.binding.frame.key); try work.metadata(stream.siUnit.symbol)
        guard !stream.producer.isEmpty, stream.configurationRevision > 0,
              checkpoint.packets.count == checkpoint.valuesInSI.count else { throw .invalidCheckpoint }
        guard checkpoint.packets.count <= work.policy.maximumPackets else {
            throw .capacity(resource: "packets", limit: work.policy.maximumPackets)
        }
        switch (checkpoint.lastTick, checkpoint.lastTargetTimeSeconds) {
        case (nil, nil): break
        case (.some(let tick), .some(let target)):
            let application = try clockTime(stream.clock, tick: tick)
            guard target.isFinite, target == application - stream.delaySeconds,
                  target >= stream.clock.epochSeconds else { throw .invalidCheckpoint }
        default: throw .invalidCheckpoint
        }
        var previous: ExternalCommandPacket?
        for index in checkpoint.packets.indices {
            let packet = checkpoint.packets[index]
            try admit(packet, stream: stream, previous: previous, work: &work)
            guard checkpoint.valuesInSI[index].isFinite else { throw .invalidCheckpoint }
            previous = packet
        }
    }

    private func admit(_ packet: ExternalCommandPacket, stream: ExternalCommandStream,
                       previous: ExternalCommandPacket?, work: inout ExternalCommandWork)
        throws(ExternalCommandError) {
        try work.metadata(packet.producer); try work.metadata(packet.model.identity)
        try work.metadata(packet.actuator.key); try work.metadata(packet.unit.symbol); try work.charge(12)
        guard packet.producer == stream.producer, packet.model == stream.binding.model,
              packet.actuator == stream.binding.actuator, packet.configurationRevision == stream.configurationRevision
            else { throw .invalidIdentity }
        guard !packet.unit.symbol.isEmpty, packet.unit.dimension == stream.siUnit.dimension,
              packet.unit.offset == 0 else { throw .incompatibleUnit }
        guard packet.value.isFinite, packet.sourceTimeSeconds.isFinite, packet.arrivalTimeSeconds.isFinite,
              packet.sourceTimeSeconds >= stream.clock.epochSeconds,
              packet.sourceTimeSeconds <= packet.arrivalTimeSeconds else { throw .invalidTime }
        if let previous {
            guard packet.sequence > previous.sequence, packet.sourceTimeSeconds > previous.sourceTimeSeconds,
                  packet.arrivalTimeSeconds >= previous.arrivalTimeSeconds else { throw .outOfOrder }
        }
    }

    private func clockTime(_ clock: ControlClock, tick: UInt64) throws(ExternalCommandError) -> Double {
        do { return try clock.time(at: tick) } catch { throw .control(error) }
    }

    private func reserve(_ count: Int, work: inout ExternalCommandWork) throws(ExternalCommandError) {
        let stride = try ExternalCommandWork.sum(MemoryLayout<ExternalCommandPacket>.stride, MemoryLayout<Double>.stride)
        try work.allocate(try ExternalCommandWork.product(count, stride))
        try work.charge(count)
    }
}
