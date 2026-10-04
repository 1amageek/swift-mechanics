import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifyLoadedSleepMechanisms() throws {
        let fixture = try LoadedSleepProbeModel(), owner = try LoadedSleepProbeContext.owner(fixture)
        let session = try LoadedSleepProbeContext.session(fixture, owner: owner)
        defer { _ = session.shutdown() }
        try enterLoadedSleep(session, owner: owner)
        let codec = NativeRuntimeCheckpointCodec(), saved = try session.checkpoint(codec: codec)
        try checkLoadedRestoreRefusals(saved)
        let (fresh, freshOwner) = try coldLoadedSession(session, saved: saved)
        defer { _ = fresh.shutdown() }
        try wakeLoadedSleep(session, owner: owner)
        try wakeLoadedSleep(fresh, owner: freshOwner)
        try require(try session.checkpoint(codec: codec) == fresh.checkpoint(codec: codec))
        print("AF23 loaded sleep: actual gravity/spring equilibrium, omission, load-change wake and fresh-owner replay passed")
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func coldLoadedSession(_ source: LoadedSleepProbeContext.Session, saved: [UInt8]) throws -> (LoadedSleepProbeContext.Session, LoadedCheckpointedMechanismSleep) {
        let freshFixture = try LoadedSleepProbeModel(), freshOwner = try LoadedSleepProbeContext.owner(freshFixture)
        try checkColdLoadedReceipt(saved, source: source, fixture: freshFixture, owner: freshOwner)
        let fresh = try LoadedSleepProbeContext.session(freshFixture, owner: freshOwner)
        do {
            let codec = NativeRuntimeCheckpointCodec()
            _ = try fresh.restart(saved, codec: codec)
            try require(try fresh.checkpoint(codec: codec) == saved)
            return (fresh, freshOwner)
        } catch { _ = fresh.shutdown(); throw error }
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkColdLoadedReceipt(_ saved: [UInt8], source: LoadedSleepProbeContext.Session, fixture: LoadedSleepProbeModel, owner: LoadedCheckpointedMechanismSleep) throws {
        let handler = LoadedSleepRuntimeCheckpointHandler(sleep: owner, revisions: ReferenceModelRevisionUpdater())
        let decoded = try NativeRuntimeCheckpointCodec().decode(saved, capacity: source.configuration.capacity)
        let admission = try handler.admitWithLoadReport(decoded, model: fixture.model, configuration: source.configuration)
        guard case .checkpointAdmission = admission.loads.scope else { throw FoundationVerificationError.analyticCheckFailed }
        try require(admission.loads.invocationsStarted == 1 && admission.loads.invocationsCompleted == 1 && admission.loads.consumed > 0)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkLoadedRestoreRefusals(_ saved: [UInt8]) throws {
        for variant in 0..<3 {
            let fixture = try LoadedSleepProbeModel(mass: variant == 0 ? 3 : 2)
            let owner = try LoadedSleepProbeContext.owner(fixture, stiffness: variant == 1 ? 22 : 20,
                energyScale: variant == 2 ? 11 : 7)
            try checkLoadedRestoreRefusal(saved, fixture: fixture, owner: owner)
        }
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkLoadedRestoreRefusal(_ saved: [UInt8], fixture: LoadedSleepProbeModel,
        owner: LoadedCheckpointedMechanismSleep) throws {
        let changed = try LoadedSleepProbeContext.session(fixture, owner: owner)
        defer { _ = changed.shutdown() }
        let codec = NativeRuntimeCheckpointCodec(), before = try changed.checkpoint(codec: codec)
        let accepted = changed.snapshot()
        var refused = false
        do throws(RuntimeFailure) { _ = try changed.restart(saved, codec: codec) }
        catch {
            try require(error.code == .incompatibleContinuation)
            try require(error.lastAccepted == accepted)
            refused = true
        }
        try require(refused && (try changed.checkpoint(codec: codec)) == before && changed.snapshot() == accepted)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func enterLoadedSleep(_ session: LoadedSleepProbeContext.Session, owner: LoadedCheckpointedMechanismSleep) throws {
        let firstWork = try startLoadedSleep(session, owner: owner)
        try settleLoadedSleep(session, owner: owner)
        try checkLoadedOmission(session, owner: owner, firstWork: firstWork)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func startLoadedSleep(_ session: LoadedSleepProbeContext.Session, owner: LoadedCheckpointedMechanismSleep) throws -> Int {
        let service: any LoadedMechanismSleepContinuing = owner
        let first = try service.stepWithLoads(session, loadBudget: LoadedSleepProbeContext.loadBudget(), maximumLoadInvocations: 100)
        guard case .equationExecution = first.loads.scope else { throw FoundationVerificationError.analyticCheckFailed }
        try require(first.loads.consumed > 0 && !first.loads.failedSupplierWorkUnavailable)
        return first.integration.work.supplierArithmeticCharged
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func settleLoadedSleep(_ session: LoadedSleepProbeContext.Session, owner: LoadedCheckpointedMechanismSleep) throws {
        let service: any LoadedMechanismSleepContinuing = owner
        _ = try service.stepWithLoads(session, loadBudget: LoadedSleepProbeContext.loadBudget(), maximumLoadInvocations: 100)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkLoadedOmission(_ session: LoadedSleepProbeContext.Session, owner: LoadedCheckpointedMechanismSleep, firstWork: Int) throws {
        let service: any LoadedMechanismSleepContinuing = owner
        let omitted = try service.stepWithLoads(session, loadBudget: LoadedSleepProbeContext.loadBudget(), maximumLoadInvocations: 100)
        let history = try LoadedSleepProbeContext.history(owner, omitted.integration.accepted)
        try require(history.mechanics.asleep.allSatisfy({ $0 }) && history.mechanics.position == [-1, -1] && history.mechanics.velocity == [0, 0])
        try require(omitted.integration.work.supplierArithmeticCharged < firstWork)
        guard case .equationExecution = omitted.loads.scope else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        try require(!omitted.loads.failedSupplierWorkUnavailable)
        for value in omitted.integration.accepted.checkpoint.physical.acceleration { try require(value == 0) }
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func wakeLoadedSleep(_ session: LoadedSleepProbeContext.Session, owner: LoadedCheckpointedMechanismSleep) throws {
        let acceptedTime = try selectLoadedWake(session, owner: owner)
        try checkWokenLoadedEvolution(session, owner: owner, acceptedTime: acceptedTime)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func selectLoadedWake(_ session: LoadedSleepProbeContext.Session, owner: LoadedCheckpointedMechanismSleep) throws -> Double {
        let service: any LoadedMechanismSleepContinuing = owner, before = session.snapshot()
        let selection = StationaryLoadSelection(programID: 2, revision: 1, generation: 1)
        var work = try MechanismProbeContext.work()
        let wake = try service.selectLoad(session, expected: before, selection: selection,
            loadBudget: LoadedSleepProbeContext.loadBudget(), maximumLoadInvocations: 100, work: &work)
        let accepted = wake.outcome.accepted, history = try LoadedSleepProbeContext.history(owner, accepted)
        try require(accepted.checkpoint.physical.time == before.checkpoint.physical.time)
        try require(accepted.checkpoint.physical.q == [-1, -1] && accepted.checkpoint.physical.v == [0, 0])
        for value in accepted.checkpoint.physical.acceleration { try require(abs(value - 2) < 1e-8) }
        try require(history.selection == selection && !history.mechanics.asleep.contains(true) && history.mechanics.lastWakeKind == 3)
        try require(accepted.checkpoint.random == before.checkpoint.random && wake.loads.consumed > 0)
        return accepted.checkpoint.physical.time
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkWokenLoadedEvolution(_ session: LoadedSleepProbeContext.Session, owner: LoadedCheckpointedMechanismSleep, acceptedTime: Double) throws {
        let service: any LoadedMechanismSleepContinuing = owner
        let evolved = try service.stepWithLoads(session, loadBudget: LoadedSleepProbeContext.loadBudget(), maximumLoadInvocations: 100)
        let state = evolved.integration.accepted.checkpoint.physical, elapsed = state.time - acceptedTime
        try require(abs(elapsed - 0.1) < 1e-12)
        // Independent RK4 polynomial for q'' = -10 * (q + 0.8), q(0) = -1, v(0) = 0.
        let expectedQ = -0.8 - 0.2 * (1 - 5 * elapsed * elapsed + (100.0 / 24) * elapsed * elapsed * elapsed * elapsed)
        let expectedV = 2 * elapsed * (1 - (10.0 / 6) * elapsed * elapsed)
        for index in state.q.indices {
            try require(abs(state.q[index] - expectedQ) < 1e-8 && abs(state.v[index] - expectedV) < 1e-8)
            try require(abs(state.acceleration[index] + 10 * (state.q[index] + 0.8)) < 1e-8)
        }
    }
}
