import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) static func verifyActuation() throws {
        let context = try ActuationProbeContext()
        defer { _ = context.session.shutdown() }
        try verifyActuationMotor(context)
        try verifyActuationContinuation(context)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func verifyActuationMotor(_ context: ActuationProbeContext) throws {
        let binding = try ActuationProbeContext.binding(model: context.model, kind: .motor)
        var work = ActuationWork(budget: context.budget), numerical = NumericalWork(budget: context.numericalBudget)
        try binding.validate(model: context.model, work: &work)
        let law = try DCMotorLaw(binding: binding, inductanceHenries: 2, resistanceOhms: 2, reciprocalConstant: 1, viscousDamping: 0.5,
            maximumVoltage: 12, maximumCurrent: 100, maximumSpeed: 10)
        let state = try ActuatorState(binding: binding, time: 0, primary: 1)
        let sample = try ActuatorSample(binding: binding, time: 0, position: 0, velocity: 2)
        let service: any LumpedActuatorEvaluating = ReferenceLumpedActuatorEvaluator()
        let response = try service.motor(law: law, state: state, sample: sample, voltage: 10, dt: 0.5, tolerance: context.tolerance, work: &work, numerical: &numerical)
        try require(response.state.primary == 2 && response.appliedEffort == 1 && response.power == 2)
        try require(response.energy.sourceWork == 10 && response.energy.mechanicalWork == 1 && response.energy.storedAfter - response.energy.storedBefore == 3)
        try require(response.energy.physicalLoss == 5 && response.energy.numericalLoss == 1 && response.energy.balanceResidual == 0)
        let row = try AffineTransmission(model: context.model.stamp, frame: context.model.descriptor.worldFrame, outputCoordinate: .rotation,
            inputCoordinates: [.rotation, .translation], gradient: [2, -0.5], prescribedRate: 1, work: &work)
        let transmitter: any ActuationTransmitting = ReferenceActuationTransmitter(mapper: LoadMapper())
        let mapped = try transmitter.affine(row, model: context.model.stamp, frame: context.model.descriptor.worldFrame, effort: 4, rate: [3, 2],
            tolerance: context.tolerance, work: &work, numerical: &numerical)
        try require(mapped.efforts == [8, -2] && mapped.virtualPower == 20 && mapped.prescribedPower == 4 && mapped.actualPower == 24)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never) private static func verifyActuationContinuation(_ context: ActuationProbeContext) throws {
        _ = try context.advance(reject: false)
        let prefix = context.session.snapshot(), codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        let checkpoint = try context.session.checkpoint(codec: codec)
        _ = try context.advance(reject: true)
        try require(context.session.snapshot() == prefix)
        _ = try context.advance(reject: false)
        let continued = context.session.snapshot()
        _ = try context.session.restart(checkpoint, codec: codec)
        try require(context.session.snapshot() == prefix)
        _ = try context.advance(reject: false)
        try require(context.session.snapshot() == continued)
        var work = ActuationWork(budget: context.budget)
        let final = try context.registry.codec.decode(continued.checkpoint.contributors[0], binding: context.law.binding, work: &work)
        try require(final.sequence == 2 && final.time == 2 && final.primary == 1)
    }
}
