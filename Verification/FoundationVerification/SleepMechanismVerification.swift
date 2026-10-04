import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifySleepMechanisms() throws {
        let model = try MechanismProbeContext.model(), owner = try SleepMechanismProbeContext.owner(model)
        let session = try SleepMechanismProbeContext.session(model, owner: owner)
        defer { _ = session.shutdown() }
        try enterMechanismSleep(session, owner: owner)
        let prefix = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        let evolved = try commandSleepingMechanism(session, owner: owner)
        _ = try session.restart(prefix, codec: NativeRuntimeCheckpointCodec())
        let replay = try commandSleepingMechanism(session, owner: owner)
        try require(replay == evolved && session.snapshot() == evolved)
        _ = try session.restart(prefix, codec: NativeRuntimeCheckpointCodec())
        try impulseSleepingMechanism(session, model: model, owner: owner)
        print("Sleep mechanism runtime verification passed: actual suspension, command/impulse wake and checkpoint replay.")
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func enterMechanismSleep(_ session: SleepMechanismProbeContext.Session, owner: CheckpointedMechanismSleep) throws {
        let service: any MechanismSleepContinuing = owner
        let first = try service.step(session)
        try require(!SleepMechanismProbeContext.history(owner, first.accepted).asleep.contains(true))
        _ = try service.step(session)
        let omitted = try service.step(session), history = try SleepMechanismProbeContext.history(owner, omitted.accepted)
        try require(history.asleep.allSatisfy({ $0 }) && history.position == [0, 0] && history.velocity == [0, 0])
        try require(omitted.work.supplierArithmeticCharged < first.work.supplierArithmeticCharged)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func commandSleepingMechanism(_ session: SleepMechanismProbeContext.Session,
                                                 owner: CheckpointedMechanismSleep) throws -> RuntimeAcceptedState {
        var work = try MechanismProbeContext.work()
        let wake = try owner.command(session, expected: session.snapshot(), drive: [6, 0], generation: 1, work: &work)
        let history = try SleepMechanismProbeContext.history(owner, wake.accepted)
        try require(!history.asleep.contains(true) && history.commandGeneration == 1 && history.lastWakeKind == 1)
        let evolved = try owner.step(session).accepted
        try require(abs(evolved.checkpoint.physical.q[0] - 0.01) < 1e-9 && abs(evolved.checkpoint.physical.q[1] + 0.005) < 1e-9)
        try require(abs(evolved.checkpoint.physical.v[0] - 0.2) < 1e-9 && abs(evolved.checkpoint.physical.v[1] + 0.1) < 1e-9)
        return evolved
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func impulseSleepingMechanism(_ session: SleepMechanismProbeContext.Session, model: CompiledMechanicalModel,
                                                 owner: CheckpointedMechanismSleep) throws {
        let source = session.snapshot()
        let impulse = try MechanismSleepImpulse(model: model.stamp, time: source.checkpoint.physical.time,
                                                acceptedSequence: source.checkpoint.acceptedSteps,
                                                layout: MechanismProbeContext.layout(), values: [6, 0])
        var work = try MechanismProbeContext.work()
        let wake = try owner.impact(session, expected: source, impulse: impulse, work: &work)
        try require(abs(wake.accepted.checkpoint.physical.v[0] - 2) < 1e-9 && abs(wake.accepted.checkpoint.physical.v[1] + 1) < 1e-9)
        try require(try SleepMechanismProbeContext.history(owner, wake.accepted).lastWakeKind == 2)
        var rejected = false
        do throws(RuntimeFailure) { _ = try owner.impact(session, expected: wake.accepted, impulse: impulse, work: &work) }
        catch { try require(error.code == .invalidOwnerAccess); rejected = true }
        try require(rejected && session.snapshot() == wake.accepted)
    }
}
