import Synchronization
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepExecution: Sendable {
    private let storage:Mutex<IslandSleepExecutionState>
    private let maximum:Int
    private let loadBudget:LoadBudget
    init(work:IslandSleepWork,maximum:Int) { storage=Mutex(IslandSleepExecutionState(work:work));self.maximum=maximum;loadBudget=work.physical.loads.budget }
    func read() -> IslandSleepWork { storage.withLock { $0.work } }
    func failure() -> IslandSleepFailureReason? { storage.withLock { $0.failure } }
    private func checkout() throws(IslandSleepFailureReason) -> IslandSleepWork {
        try storage.withLock { (state:inout IslandSleepExecutionState) throws(IslandSleepFailureReason) in
            guard !state.busy,!state.work.failedSupplierWorkUnavailable,state.work.supplierInvocations < maximum else { throw .runtime(RuntimeFailure(.capacityExceeded,message:"Island supplier invocation capacity/busy receipt.")) }
            state.busy=true;return state.work
        }
    }
    private func finish(_ work:IslandSleepWork,failure:IslandSleepFailureReason?) {
        storage.withLock { $0.work=work;$0.failure=failure;$0.busy=false }
    }
    func reserveOwned(_ count:Int,integration:inout NumericalWork) throws(RuntimeFailure) {
        do throws(NumericalError) {
            try integration.requireStorage(count)
            try storage.withLock { (state:inout IslandSleepExecutionState) throws(NumericalError) in try state.work.physical.numerical.requireStorage(count) }
        } catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Owned island stage storage exceeds scratch capacity.") }
    }
    func reserveEncoding(_ count:Int) throws(RuntimeFailure) {
        do throws(NumericalError) { try storage.withLock { (state:inout IslandSleepExecutionState) throws(NumericalError) in try state.work.contributorEncoding.requireStorage(count) } }
        catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Owned island encoding storage exceeds capacity.") }
    }
    @inline(never)
    func invoke<T>(integration:inout NumericalWork,reserved:Int = 0,
        _ body:(inout StationaryIslandWork) throws(StationaryIslandFailure) -> T) throws(RuntimeFailure) -> T {
        var total:IslandSleepWork
        do throws(IslandSleepFailureReason) { total=try checkout() }
        catch { throw Self.runtime(error) }
        var local=StationaryIslandWork(numerical:NumericalWork(budget:integration.budget),loads:total.physical.loads)
        var admitted=false
        do {
            let own=try total.physical.numerical.remainingBudget(reservedStorage:reserved)
            let stage=try integration.remainingBudget(reservedStorage:reserved)
            let budget=try NumericalBudget(scalarStorage:min(own.scalarStorage,stage.scalarStorage),arithmeticOperations:min(own.arithmeticOperations,stage.arithmeticOperations),iterations:min(own.iterations,stage.iterations))
            guard !loadBudget.isCancelled() else { throw LoadError.cancelled }
            local=StationaryIslandWork(numerical:NumericalWork(budget:budget),loads:total.physical.loads);admitted=true
            try local.numerical.requireStorage(1);try local.numerical.chargeOperations(1)
            try local.loads.reserve(scalars:1);try local.loads.charge(1)
            total.supplierInvocations += 1
        } catch {
            if admitted {
                do throws(NumericalError) { try total.physical.numerical.absorb(local.numerical,reservedStorage:reserved);try integration.absorb(local.numerical,reservedStorage:reserved) }
                catch { total.failedSupplierWorkUnavailable=true }
                total.physical.loads=local.loads
            }
            let failure=RuntimeFailure(loadBudget.isCancelled() ? .cancelled : .contributorBudgetExceeded,message:"Island supplier admission quantum exceeds capacity/cancelled.")
            finish(total,failure:.runtime(failure));throw failure
        }
        let known=local
        var result:T?,cause:IslandSleepFailureReason?
        do throws(StationaryIslandFailure) { result=try body(&local) }
        catch { cause = .physical(error);total.failedSupplierWorkUnavailable = total.failedSupplierWorkUnavailable || error.failedSupplierWorkUnavailable }
        let valid=IslandSleepBits.valid(local.numerical,known.numerical) && local.loads.budget.maximumWork == known.loads.budget.maximumWork && local.loads.budget.maximumScalars == known.loads.budget.maximumScalars && local.loads.consumed >= known.loads.consumed && local.loads.peakScalars >= known.loads.peakScalars
        if !valid { local=known;total.failedSupplierWorkUnavailable=true;cause = .supplierLedgerFailure(cause) }
        do {
            try total.physical.numerical.absorb(local.numerical,reservedStorage:reserved)
            try integration.absorb(local.numerical,reservedStorage:reserved)
            total.physical.loads=local.loads
            if !loadBudget.isCancelled() {
                var canonical=LoadWork(budget:loadBudget)
                try canonical.charge(local.loads.consumed);try canonical.reserve(scalars:local.loads.peakScalars)
                total.physical.loads=canonical
            } else {
                cause = cause ?? .runtime(RuntimeFailure(.cancelled,message:"Island load scope cancelled after supplier."))
            }
        } catch {
            total.failedSupplierWorkUnavailable=true
            if cause == nil { cause = .runtime(RuntimeFailure(.contributorBudgetExceeded,message:"Island known receipt finalization failed.",failedSupplierWorkUnavailable:true)) }
        }
        total.failedSupplierWorkUnavailable = total.failedSupplierWorkUnavailable || local.failedSupplierWorkUnavailable
        finish(total,failure:cause)
        if let cause { throw Self.runtime(cause) }
        guard let result else { throw RuntimeFailure(.invalidState,message:"Island supplier returned no value.") };return result
    }
    @inline(never)
    func encode<T>(_ body:(inout NumericalWork) throws(RuntimeFailure) -> T) throws(RuntimeFailure) -> T {
        var total:IslandSleepWork
        do throws(IslandSleepFailureReason) { total=try checkoutEncoding() } catch { throw Self.runtime(error) }
        do throws(NumericalError) { try total.contributorEncoding.requireStorage(1);try total.contributorEncoding.chargeOperations(1) }
        catch { finish(total,failure:.numerical(error));throw RuntimeFailure(.contributorBudgetExceeded,message:"Encoding admission quantum exceeded.") }
        let known=total.contributorEncoding
        var result:T?,failure:RuntimeFailure?
        do throws(RuntimeFailure) { result=try body(&total.contributorEncoding) } catch { failure=error }
        guard IslandSleepBits.valid(total.contributorEncoding,known) else {
            total.contributorEncoding=known;total.failedSupplierWorkUnavailable=true
            finish(total,failure:.supplierLedgerFailure(failure.map { .runtime($0) }))
            throw RuntimeFailure(.invalidOwnerAccess,message:"Encoding supplier reset authoritative ledger.",failedSupplierWorkUnavailable:true)
        }
        total.failedSupplierWorkUnavailable = total.failedSupplierWorkUnavailable || (failure?.failedSupplierWorkUnavailable ?? false)
        finish(total,failure:failure.map { .runtime($0) })
        if let failure { throw failure };guard let result else { throw RuntimeFailure(.invalidState,message:"Missing encoded result.") };return result
    }
    private func checkoutEncoding() throws(IslandSleepFailureReason) -> IslandSleepWork {
        try storage.withLock { (s:inout IslandSleepExecutionState) throws(IslandSleepFailureReason) in
            guard !s.busy else { throw .runtime(RuntimeFailure(.busy,message:"Overlapping island receipt operation.")) };s.busy=true;return s.work
        }
    }
    static func runtime(_ reason:IslandSleepFailureReason) -> RuntimeFailure {
        switch reason {
        case .runtime(let f):return f
        case .physical(let f):
            if case .cancelled=f.reason { return RuntimeFailure(.cancelled,message:"Island physical supplier cancelled.",failedSupplierWorkUnavailable:f.failedSupplierWorkUnavailable) }
            return RuntimeFailure(.invalidState,message:"Island physical supplier refused source/law.",failedSupplierWorkUnavailable:f.failedSupplierWorkUnavailable)
        case .supplierLedgerFailure(let original):
            if let original,Self.runtime(original).code == .cancelled { return RuntimeFailure(.cancelled,message:"Cancelled supplier reset ledger.",failedSupplierWorkUnavailable:true) }
            return RuntimeFailure(.invalidOwnerAccess,message:"Island supplier replaced/reset known work.",failedSupplierWorkUnavailable:true)
        default:return RuntimeFailure(.contributorBudgetExceeded,message:"Island work admission failed.")
        }
    }
}
