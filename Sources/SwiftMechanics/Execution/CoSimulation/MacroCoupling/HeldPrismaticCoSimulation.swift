import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class HeldPrismaticCoSimulation: CoSimulationOperating, Sendable {
    private let first: any CoSimulationPhysicalParticipant
    private let second: any CoSimulationPhysicalParticipant
    private let coupling: CoSimulationCoupling
    private let state: Mutex<CoSimulationState>
    init(first: PrismaticCoSimulationParticipant, second: PrismaticCoSimulationParticipant,
         coupling: CoSimulationCoupling, boundary: CoSimulationBoundary) {
        self.first=first; self.second=second; self.coupling=coupling; state=Mutex(CoSimulationState(boundary:boundary))
    }
    func snapshot() throws(CoSimulationFailure) -> CoSimulationBoundary {
        try state.withLock { value throws(CoSimulationFailure) in
            guard value.terminalFailure == nil else { throw .refusal(.poisoned) }
            guard !value.closed else { throw .refusal(.closed) }
            guard !value.busy else { throw .refusal(.busy) }
            return CoSimulationBoundary(first:value.boundary.first,second:value.boundary.second,work:value.work,
                defect:value.boundary.accumulatedAbsoluteEnergyDefectJoules)
        }
    }
    func status() -> CoSimulationStatus {
        state.withLock { CoSimulationStatus(busy:$0.busy,closed:$0.closed,failure:$0.terminalFailure,work:$0.work) }
    }
    private func begin(tick: UInt64, time: Double) throws(CoSimulationFailure) -> CoSimulationBoundary {
        try state.withLock { value throws(CoSimulationFailure) in
            guard value.terminalFailure == nil else { throw .refusal(.poisoned) }
            guard !value.closed else { throw .refusal(.closed) }
            guard !value.busy else { throw .refusal(.busy) }
            guard !Task.isCancelled else { throw .refusal(.cancelled) }
            guard tick == value.boundary.tick, time == value.boundary.timeSeconds else { throw .refusal(.staleBoundary) }
            value.busy=true
            return CoSimulationBoundary(first:value.boundary.first,second:value.boundary.second,work:value.work,
                defect:value.boundary.accumulatedAbsoluteEnergyDefectJoules)
        }
    }
    private func publish(_ receipt: CoSimulationMacroReceipt) throws(CoSimulationFailure) {
        try state.withLock { value throws(CoSimulationFailure) in
            guard !value.closed else { throw .refusal(.closed) }
            guard value.terminalFailure == nil, value.busy else { throw .refusal(.poisoned) }
            value.boundary=receipt.boundary; value.work=receipt.boundary.work; value.busy=false
        }
    }
    private func finishFailure(_ failure: CoSimulationFailure, work: CoSimulationWorkLedger, poison: Bool) {
        state.withLock { value in
            value.work=work; value.busy=false
            if poison { value.terminalFailure=failure }
        }
    }
    @inline(never)
    func step(expectedTick: UInt64, expectedTimeSeconds: Double) throws(CoSimulationFailure) -> CoSimulationMacroReceipt {
        let source=try begin(tick:expectedTick,time:expectedTimeSeconds)
        var work=source.work
        var checkpoints: (first: [UInt8], second: [UInt8])?
        var mutationAttempted=false
        var firstKnown=source.first.accepted, secondKnown=source.second.accepted
        do throws(CoSimulationFailure) {
            checkpoints=try prepareCheckpoints(source:source,work:&work)
            let force=try CoSimulationEvidence.heldForce(source,coupling:coupling)
            mutationAttempted=true
            let a=try advance(first,from:source.first,effort:force,known:&firstKnown,work:&work)
            let b=try advance(second,from:source.second,effort:-force,known:&secondKnown,work:&work)
            return try accept(source:source,first:a,second:b,force:force,work:work)
        } catch {
            if mutationAttempted, let checkpoints {
                throw recover(error,source:source,firstBytes:checkpoints.first,secondBytes:checkpoints.second,
                    firstKnown:firstKnown,secondKnown:secondKnown,work:work)
            }
            throw rejectBeforeMutation(error,source:source,work:work)
        }
    }
    // Phase boundaries limit simultaneous Native frame lifetimes without changing supplier order or state authority.
    @inline(never)
    private func prepareCheckpoints(source: CoSimulationBoundary, work: inout CoSimulationWorkLedger)
        throws(CoSimulationFailure) -> (first: [UInt8], second: [UInt8]) {
        try work.beginMacro()
        let retained=try CoSimulationWorkLedger.add(first.configuration.control.runtimeCapacity.maximumCheckpointBytes,
            second.configuration.control.runtimeCapacity.maximumCheckpointBytes)
        guard retained <= work.budget.maximumRetainedCheckpointBytes else { throw .refusal(.capacity) }
        try work.reserve(.checkpoint,first.configuration); let firstBytes=try first.checkpoint()
        try work.reserve(.checkpoint,second.configuration); let secondBytes=try second.checkpoint()
        try first.verifyCheckpoint(firstBytes,expected:source.first)
        try second.verifyCheckpoint(secondBytes,expected:source.second)
        // Every possible restart and verification observation is precharged before any physical mutation.
        try work.reserve(.restart,first.configuration); try work.reserve(.observe,first.configuration)
        try work.reserve(.restart,second.configuration); try work.reserve(.observe,second.configuration)
        try work.reserve(.encoder,first.configuration); try work.reserve(.step,first.configuration)
        try work.reserve(.encoder,second.configuration); try work.reserve(.step,second.configuration)
        return (firstBytes,secondBytes)
    }
    @inline(never)
    private func advance(_ participant: any CoSimulationPhysicalParticipant, from observation: ControlObservation,
                         effort: Double, known: inout RuntimeAcceptedState, work: inout CoSimulationWorkLedger)
        throws(CoSimulationFailure) -> ControlStepResult {
        var encoderWork=NumericalWork(budget:participant.configuration.encoderBudget)
        let result: ControlStepResult
        do { result=try participant.advance(from:observation,effort:effort,work:&encoderWork) }
        catch {
            if let prefix=error.supplierPrefix { known=prefix }
            try work.record(encoderWork,expectedBudget:participant.configuration.encoderBudget)
            throw error
        }
        known=result.observation.accepted
        try work.record(encoderWork,expectedBudget:participant.configuration.encoderBudget)
        try work.record(result)
        return result
    }
    @inline(never)
    private func accept(source: CoSimulationBoundary, first a: ControlStepResult, second b: ControlStepResult,
                        force: Double, work: CoSimulationWorkLedger) throws(CoSimulationFailure) -> CoSimulationMacroReceipt {
        let receipt=try CoSimulationEvidence.receipt(source:source,first:a,second:b,
            firstConfiguration:first.configuration,secondConfiguration:second.configuration,
            coupling:coupling,force:force,work:work)
        guard !Task.isCancelled else { throw .refusal(.cancelled) }
        try publish(receipt)
        return receipt
    }
    @inline(never)
    private func rejectBeforeMutation(_ original: CoSimulationFailure, source: CoSimulationBoundary,
                                      work: CoSimulationWorkLedger) -> CoSimulationFailure {
        let failure=CoSimulationFailure(original.cause,
            first:CoSimulationOwnerPrefix(participant:first.configuration.identity,current:source.first.accepted,restored:false),
            second:CoSimulationOwnerPrefix(participant:second.configuration.identity,current:source.second.accepted,restored:false),
            work:work,unavailable:original.failedSupplierWorkUnavailable)
        finishFailure(failure,work:work,poison:original.failedSupplierWorkUnavailable)
        return failure
    }
    private func restore(_ participant: any CoSimulationPhysicalParticipant, bytes: [UInt8], expected: ControlObservation, known: RuntimeAcceptedState,
                         failures: inout [CoSimulationFailure]) -> CoSimulationOwnerPrefix {
        var lastKnown=known
        var current: RuntimeAcceptedState?, restartSucceeded=false, verificationSucceeded=false
        do { try participant.restart(bytes); restartSucceeded=true }
        catch { failures.append(error); current=error.supplierPrefix; if let current { lastKnown=current } }
        // Do not clear Task cancellation or replace this operation with a fabricated successful restore.
        do {
            let observation=try participant.observe(); current=observation.accepted; lastKnown=observation.accepted
            if observation.accepted == expected.accepted { verificationSucceeded=true }
            else { failures.append(.refusal(.originalEvidenceRejected)) }
        } catch { failures.append(error); current=error.supplierPrefix ?? current; if let current { lastKnown=current } }
        return CoSimulationOwnerPrefix(participant:participant.configuration.identity,current:current,lastKnown:lastKnown,
            restored:restartSucceeded && verificationSucceeded)
    }
    private func recover(_ original: CoSimulationFailure, source: CoSimulationBoundary, firstBytes: [UInt8], secondBytes: [UInt8],
                         firstKnown: RuntimeAcceptedState, secondKnown: RuntimeAcceptedState, work: CoSimulationWorkLedger) -> CoSimulationFailure {
        var failures: [CoSimulationFailure]=[]
        let a=restore(first,bytes:firstBytes,expected:source.first,known:firstKnown,failures:&failures)
        let b=restore(second,bytes:secondBytes,expected:source.second,known:secondKnown,failures:&failures)
        let unavailable=original.failedSupplierWorkUnavailable || failures.contains(where:{$0.failedSupplierWorkUnavailable})
        let irrecoverable = !a.restored || !b.restored
        let failure=CoSimulationFailure(irrecoverable ? .irrecoverablePrefix : original.cause,
            first:a,second:b,recovery:[original]+failures,work:work,unavailable:unavailable)
        finishFailure(failure,work:work,poison:irrecoverable || unavailable)
        return failure
    }
    deinit { _=first.shutdown(); _=second.shutdown() }
    func shutdown() -> RuntimeShutdownStatus {
        state.withLock { $0.closed=true }
        let a=first.shutdown(), b=second.shutdown()
        return a == .closed && b == .closed ? .closed : .draining
    }
}
