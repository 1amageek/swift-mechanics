import SwiftMechanics

public enum ExternalCommandQualificationCases {
    private typealias F = ExternalCommandQualificationFixtures
    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw ExternalCommandQualificationError.assertion(message) }
    }
    private static func near(_ actual: Double, _ expected: Double, _ message: String) throws {
        try require(actual.isFinite && abs(actual - expected) <= 1e-10 * max(1, abs(expected)), message)
    }
    private static func failure(_ expected: String, _ operation: () throws(ExternalCommandError) -> Void) throws {
        do throws(ExternalCommandError) { try operation() }
        catch {
            let observed: String
            switch error {
            case .outOfOrder: observed = "order"
            case .stalePacket: observed = "late"
            case .staleTick: observed = "tick"
            case .synchronizationUnavailable: observed = "synchronization"
            case .ageExceeded: observed = "age"
            case .gapExceeded: observed = "gap"
            case .incompatibleUnit: observed = "unit"
            case .invalidIdentity: observed = "identity"
            case .invalidTime: observed = "time"
            case .incompatibleBinding: observed = "binding"
            case .capacity(let resource, _): observed = resource
            case .integerOverflow: observed = "overflow"
            case .cancelled: observed = "cancelled"
            case .actuation: observed = "actuation"
            case .control: observed = "clock"
            default: observed = "other"
            }
            try require(observed == expected, "Original typed failure changed: " + expected + " / " + observed)
            return
        }
        throw ExternalCommandQualificationError.assertion("Unexpected successful command: " + expected)
    }

    public static func delayedLinearAndExactSI() throws {
        let scheduler: any ExternalCommandScheduling = ReferenceExternalCommandScheduler()
        let empty = try F.checkpoint(), degree = try UnitDefinition(symbol: "deg", dimension: .angle, scale: Double.pi / 180, offset: 0)
        let packets = try [F.packet(empty, sequence: 10, source: 0, arrival: 0, value: 0, unit: degree),
                          F.packet(empty, sequence: 11, source: 0.5, arrival: 0.5, value: 60, unit: degree),
                          F.packet(empty, sequence: 12, source: 1, arrival: 1, value: 120, unit: degree)]
        var work = try F.work()
        let stream = try scheduler.append(packets, to: empty, converter: SIUnitConverter(), work: &work)
        let selected = try scheduler.select(tick: 2, from: stream, work: &work)
        try near(selected.applicationTimeSeconds, 0.5, "Clock application time")
        try near(selected.targetSourceTimeSeconds, 0.25, "Declared source delay")
        try near(selected.firstWeight, 0.5, "Left interpolation weight")
        try near(selected.secondWeight, 0.5, "Right interpolation weight")
        try near(selected.command.value, Double.pi / 6, "Original degrees to radians")
        try require(selected.firstPacket == packets[0] && selected.secondPacket == packets[1], "Original source packet identity")
        try require(selected.actuator == empty.stream.binding && selected.command.mode == .position, "Real drive command binding")
        try require(stream.lastTick == nil && empty.packets.isEmpty, "Selection mutated prior checkpoint")
        let exactEmpty = try F.checkpoint(interpolation: .exact)
        let exactStream = try scheduler.append(packets, to: exactEmpty, converter: SIUnitConverter(), work: &work)
        let exact = try scheduler.select(tick: 3, from: exactStream, work: &work)
        try near(exact.command.value, Double.pi / 3, "Exact selected SI command")
        try require(exact.secondPacket == nil && exact.firstWeight == 1 && exact.firstPacket.sequence == 11, "Exact endpoint source")
        try failure("synchronization") { () throws(ExternalCommandError) in _ = try scheduler.select(tick: 2, from: exactStream, work: &work) }
    }

    public static func holdRestorePruneAndReplay() throws {
        let scheduler: any ExternalCommandScheduling = ReferenceExternalCommandScheduler()
        let empty = try F.checkpoint(interpolation: .zeroOrderHold)
        let packets = try [F.packet(empty, sequence: 10, source: 0, arrival: 0, value: 2),
                          F.packet(empty, sequence: 11, source: 0.5, arrival: 0.5, value: 4),
                          F.packet(empty, sequence: 12, source: 1, arrival: 1, value: 8)]
        var work = try F.work()
        let stream = try scheduler.append(packets, to: empty, converter: SIUnitConverter(), work: &work)
        let first = try scheduler.select(tick: 2, from: stream, work: &work)
        try near(first.command.value, 2, "Held original older endpoint")
        let replay = try scheduler.select(tick: 2, from: stream, work: &work)
        try require(replay.firstPacket == first.firstPacket && replay.command == first.command && replay.nextCheckpoint.lastTick == 2, "Exact checkpoint replay")
        let restored = try scheduler.restore(stream: stream.stream, packets: packets, lastTick: 2, converter: SIUnitConverter(), work: &work)
        try require(restored.lastTargetTimeSeconds == first.targetSourceTimeSeconds && restored.valuesInSI == stream.valuesInSI, "Restore actual source selection")
        let later = try scheduler.select(tick: 4, from: restored, work: &work)
        try near(later.command.value, 4, "Held later endpoint")
        let pruned = try scheduler.prune(later.nextCheckpoint, work: &work)
        try require(pruned.packets == Array(packets[1...]) && pruned.valuesInSI == [4, 8] && pruned.lastTick == 4, "Prune retains preceding source endpoint")
        let next = try scheduler.select(tick: 5, from: pruned, work: &work)
        try near(next.command.value, 8, "Pruned continuation")
        try failure("tick") { () throws(ExternalCommandError) in _ = try scheduler.select(tick: 4, from: pruned, work: &work) }
        let late = try F.packet(empty, sequence: 13, source: 0.75, arrival: 1.25, value: 10)
        let oldOnly = try scheduler.append(Array(packets[0...1]), to: empty, converter: SIUnitConverter(), work: &work)
        let selectedOld = try scheduler.select(tick: 4, from: oldOnly, work: &work)
        try failure("late") { () throws(ExternalCommandError) in _ = try scheduler.append([late], to: selectedOld.nextCheckpoint, converter: SIUnitConverter(), work: &work) }
    }

    public static func actualServoMechanicalWork() throws {
        let scheduler: any ExternalCommandScheduling = ReferenceExternalCommandScheduler()
        let empty = try F.checkpoint(interpolation: .exact, delay: 0, translation: true, mode: .effort)
        let unit = try UnitDefinition(symbol: "kN", dimension: .force, scale: 1000, offset: 0)
        let packet = try F.packet(empty, sequence: 1, source: 0, arrival: 0, value: 0.002, unit: unit)
        var work = try F.work(), actuator = try F.actuationWork(), numerical = try F.numericalWork()
        let checkpoint = try scheduler.append([packet], to: empty, converter: SIUnitConverter(), work: &work)
        let binding = checkpoint.stream.binding
        let law = try ScalarServo(binding: binding, positionGain: 0, velocityGain: 0, integralGain: 0, integralLimit: 10, effortLimit: 10, speedLimit: 20, positionDeadband: 0, velocityDeadband: 0, filterTimeConstant: 0)
        let state = try ActuatorState(binding: binding, time: 0, primary: 0, secondary: 0, mode: .effort, sequence: 7)
        let sample = try ActuatorSample(binding: binding, time: 0, position: 0.1, velocity: 3)
        let evaluator: any DriveEvaluating = ReferenceDriveEvaluator()
        let energyTolerance = try F.tolerance()
        let result = try scheduler.drive(tick: 0, from: checkpoint, law: law, state: state, sample: sample, evaluator: evaluator,
                                         energyTolerance: energyTolerance, actuationWork: &actuator, numericalWork: &numerical, work: &work)
        try near(result.selection.command.value, 2, "Original kiloNewton command")
        try near(result.actuatorResponse.appliedEffort, 2, "Actual supplier force")
        try near(result.actuatorResponse.power, 6, "Original F times v mechanical power")
        try near(result.actuatorResponse.energy.mechanicalWork, 1.5, "Original force times velocity times interval")
        try near(result.actuatorResponse.energy.sourceWork, 1.5, "Original source energy")
        try near(result.actuatorResponse.energy.balanceResidual, 0, "Actual energy balance")
        try require(result.actuatorResponse.state.time == 0.25 && result.actuatorResponse.state.sequence == 8 && result.intervalEndTimeSeconds == 0.25, "Actual clock interval and actuator sequence")
        try require(checkpoint.lastTick == nil && state.sequence == 7, "Drive mutated original state")
        let wrongSample = try ActuatorSample(binding: binding, time: 0.25, position: 0.1, velocity: 3)
        try failure("binding") { () throws(ExternalCommandError) in
            _ = try scheduler.drive(tick: 0, from: checkpoint, law: law, state: state, sample: wrongSample, evaluator: evaluator,
                                    energyTolerance: energyTolerance, actuationWork: &actuator, numericalWork: &numerical, work: &work)
        }
        var exhausted = try F.actuationWork()
        let noScalars = try ActuationBudget(maximumWork: 0, maximumScalars: 0, maximumBytes: 0, maximumBindings: 0, maximumMetadataBytes: 0)
        exhausted = ActuationWork(budget: noScalars)
        try failure("actuation") { () throws(ExternalCommandError) in
            _ = try scheduler.drive(tick: 0, from: checkpoint, law: law, state: state, sample: sample, evaluator: evaluator,
                                    energyTolerance: energyTolerance, actuationWork: &exhausted, numericalWork: &numerical, work: &work)
        }
    }

    public static func arrivalAgeGapAndClockRefusals() throws {
        let scheduler: any ExternalCommandScheduling = ReferenceExternalCommandScheduler()
        let empty = try F.checkpoint()
        let first = try F.packet(empty, sequence: 1, source: 0, arrival: 0, value: 0)
        let unseen = try F.packet(empty, sequence: 2, source: 0.5, arrival: 1, value: 2)
        var work = try F.work()
        let stream = try scheduler.append([first, unseen], to: empty, converter: SIUnitConverter(), work: &work)
        try failure("synchronization") { () throws(ExternalCommandError) in _ = try scheduler.select(tick: 2, from: stream, work: &work) }
        try failure("synchronization") { () throws(ExternalCommandError) in _ = try scheduler.select(tick: 0, from: stream, work: &work) }
        try failure("clock") { () throws(ExternalCommandError) in _ = try scheduler.select(tick: 41, from: stream, work: &work) }
        let agedEmpty = try F.checkpoint(interpolation: .zeroOrderHold, age: 0.25)
        let aged = try scheduler.append([first], to: agedEmpty, converter: SIUnitConverter(), work: &work)
        try failure("age") { () throws(ExternalCommandError) in _ = try scheduler.select(tick: 2, from: aged, work: &work) }
        let gapEmpty = try F.checkpoint(gap: 0.25)
        let right = try F.packet(gapEmpty, sequence: 2, source: 0.5, arrival: 0.5, value: 2)
        let wide = try scheduler.append([first, right], to: gapEmpty, converter: SIUnitConverter(), work: &work)
        try failure("gap") { () throws(ExternalCommandError) in _ = try scheduler.select(tick: 2, from: wide, work: &work) }
        try require(stream.lastTick == nil && stream.valuesInSI == [0, 2], "Failed query mutated checkpoint")
    }

    public static func originalIdentityUnitsOrderAndFailureWork() throws {
        let scheduler: any ExternalCommandScheduling = ReferenceExternalCommandScheduler()
        let empty = try F.checkpoint()
        let first = try F.packet(empty, sequence: 1, source: 0, arrival: 0, value: 1)
        var work = try F.work()
        let stream = try scheduler.append([first], to: empty, converter: SIUnitConverter(), work: &work)
        let duplicate = try F.packet(empty, sequence: 1, source: 0.5, arrival: 0.5, value: 2)
        let before = work.operations
        try failure("order") { () throws(ExternalCommandError) in _ = try scheduler.append([duplicate], to: stream, converter: SIUnitConverter(), work: &work) }
        try require(work.operations > before && stream.packets == [first] && empty.packets.isEmpty, "Failed admission retained known work atomically")
        let foreign = try F.packet(empty, sequence: 2, source: 0.5, arrival: 0.5, value: 2, producer: "foreign-clock")
        try failure("identity") { () throws(ExternalCommandError) in _ = try scheduler.append([foreign], to: stream, converter: SIUnitConverter(), work: &work) }
        let metres = try UnitDefinition(symbol: "m", dimension: .length, scale: 1, offset: 0)
        let badUnit = try F.packet(empty, sequence: 2, source: 0.5, arrival: 0.5, value: 2, unit: metres)
        try failure("unit") { () throws(ExternalCommandError) in _ = try scheduler.append([badUnit], to: stream, converter: SIUnitConverter(), work: &work) }
        let invalid = try F.packet(empty, sequence: 2, source: 0.5, arrival: 0.25, value: 2)
        try failure("time") { () throws(ExternalCommandError) in _ = try scheduler.append([invalid], to: stream, converter: SIUnitConverter(), work: &work) }
    }

    public static func capacitiesAndOverflow() throws {
        let scheduler: any ExternalCommandScheduling = ReferenceExternalCommandScheduler()
        let empty = try F.checkpoint(), packet = try F.packet(empty, sequence: 1, source: 0, arrival: 0, value: 1)
        var packets = try F.work(packets: 0), batch = try F.work(batch: 0), allocation = try F.work(allocation: 0), metadata = try F.work(metadata: 0), operations = try F.work(operations: 0)
        try failure("packets") { () throws(ExternalCommandError) in _ = try scheduler.append([packet], to: empty, converter: SIUnitConverter(), work: &packets) }
        try failure("batch") { () throws(ExternalCommandError) in _ = try scheduler.append([packet], to: empty, converter: SIUnitConverter(), work: &batch) }
        try failure("allocationBytes") { () throws(ExternalCommandError) in _ = try scheduler.append([packet], to: empty, converter: SIUnitConverter(), work: &allocation) }
        try failure("metadataBytes") { () throws(ExternalCommandError) in _ = try scheduler.append([packet], to: empty, converter: SIUnitConverter(), work: &metadata) }
        try failure("work") { () throws(ExternalCommandError) in _ = try scheduler.append([packet], to: empty, converter: SIUnitConverter(), work: &operations) }
        try failure("overflow") { () throws(ExternalCommandError) in _ = try ExternalCommandWork.product(Int.max, 2) }
        try require(packets.operations > 0 && operations.operations == 0 && allocation.allocationBytes == 0 && empty.packets.isEmpty, "Explicit bounded work and no partial publication")
    }

    public static func actualTaskCancellation(checkpoint: ExternalCommandCheckpoint) throws {
        let scheduler: any ExternalCommandScheduling = ReferenceExternalCommandScheduler()
        var work = try F.work()
        try failure("cancelled") { () throws(ExternalCommandError) in
            _ = try scheduler.append([], to: checkpoint, converter: SIUnitConverter(), work: &work)
        }
        try require(work.operations == 0 && checkpoint.packets.isEmpty && checkpoint.lastTick == nil, "Cancelled public operation published no command")
    }
}
