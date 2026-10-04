import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class StationaryLoadExecution:StationaryLoadExecuting, Sendable {
    private struct State:Sendable {
        var consumed=0,peak=0,started=0,completed=0
        var active:Int?,known:LoadWork?
        var provisional=0
        var failed=false,closed=false,unknown=false
    }
    private let state=Mutex(State())
    public let scope:StationaryLoadWorkReport.Scope
    public let budget:LoadBudget
    public let maximumInvocations:Int
    private let scalars:Int
    public init(scope:StationaryLoadWorkReport.Scope,budget:LoadBudget,maximumInvocations:Int,requiredScalars:Int) throws(StationaryLoadError) {
        guard maximumInvocations >= 0,requiredScalars >= 0 else { throw .invalidInput }
        self.scope=scope;self.budget=budget;self.maximumInvocations=maximumInvocations;scalars=requiredScalars
    }
    public func beginInvocation() throws(StationaryLoadError) -> StationaryLoadInvocation {
        let claim:(Int,Int,StationaryLoadError?)=state.withLock { s in
            if s.active != nil { return (0,0,.busy) }
            if s.closed || s.failed { return (0,0,.invalidInput) }
            if s.started >= maximumInvocations { s.failed=true;return (0,0,.invocationLimit) }
            s.started+=1;s.active=s.started
            return (s.started,budget.maximumWork-s.consumed,nil)
        }
        if let failure=claim.2 { throw failure }
        let localBudget:LoadBudget
        do throws(LoadError) { localBudget=try LoadBudget(maximumWork:claim.1,maximumScalars:budget.maximumScalars,isCancelled:budget.isCancelled) }
        catch { state.withLock { s in s.active=nil;s.failed=true;s.completed+=1 };throw .loads(error) }
        var work=LoadWork(budget:localBudget)
        do throws(LoadError) { try work.reserve(scalars:scalars);try work.charge(1) }
        catch {
            state.withLock { s in s.peak=max(s.peak,work.peakScalars);s.consumed+=work.consumed;s.active=nil;s.failed=true;s.completed+=1 }
            throw .loads(error)
        }
        let sealed=state.withLock { s in
            if s.closed || s.failed || s.active != claim.0 {
                s.consumed+=work.consumed;s.peak=max(s.peak,work.peakScalars);s.active=nil;s.known=nil;s.completed+=1;s.failed=true
                return true
            }
            s.known=work;return false
        }
        guard !sealed else { throw .supplierLedgerFailure }
        return StationaryLoadInvocation(owner:self,ticket:claim.0,work:work)
    }
    public func finishInvocation(_ invocation:StationaryLoadInvocation,work:LoadWork,failedSupplierWorkUnavailable:Bool) throws(StationaryLoadError) {
        // Cancellation callbacks are always outside the storage lock.
        let cancelled=budget.isCancelled()
        let failure:StationaryLoadError?=state.withLock { s in
            guard invocation.owner === self,s.active == invocation.ticket,let known=s.known else { s.failed=true;s.unknown=true;return .supplierLedgerFailure }
            let valid=work.budget.maximumWork == known.budget.maximumWork && work.budget.maximumScalars == known.budget.maximumScalars && work.consumed >= known.consumed && work.peakScalars >= known.peakScalars && work.consumed <= work.budget.maximumWork && work.peakScalars <= work.budget.maximumScalars
            let retained=valid ? work : known
            s.consumed+=retained.consumed-s.provisional;s.provisional=0;s.peak=max(s.peak,retained.peakScalars);s.active=nil;s.known=nil;s.completed+=1
            s.unknown = s.unknown || failedSupplierWorkUnavailable || !valid
            if !valid || s.closed { s.failed=true;return .supplierLedgerFailure }
            if cancelled { s.failed=true;return .cancelled }
            if failedSupplierWorkUnavailable { s.failed=true }
            return nil
        }
        if let failure { throw failure }
    }
    public func report() -> StationaryLoadWorkReport { state.withLock { receipt($0) } }
    public func close() -> StationaryLoadWorkReport {
        state.withLock { s in
            if s.active != nil {
                if let known=s.known { s.consumed+=known.consumed-s.provisional;s.provisional=known.consumed;s.peak=max(s.peak,known.peakScalars) }
                s.unknown=true;s.failed=true
            }
            s.closed=true;return receipt(s)
        }
    }
    private func receipt(_ s:State) -> StationaryLoadWorkReport {
        StationaryLoadWorkReport(scope:scope,admission:.admitted,maximumWork:budget.maximumWork,maximumScalars:budget.maximumScalars,maximumInvocations:maximumInvocations,consumed:s.consumed,peakScalars:s.peak,invocationsStarted:s.started,invocationsCompleted:s.completed,failedSupplierWorkUnavailable:s.unknown)
    }
}
