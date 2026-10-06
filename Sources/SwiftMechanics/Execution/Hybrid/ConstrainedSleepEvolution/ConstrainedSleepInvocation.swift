internal enum ConstrainedSleepInvocation {
    @inline(never)
    static func collision<T>(_ work:inout ConstrainedSleepEvolutionWork,_ body:(inout CollisionWork) throws(HybridError) -> T) throws(ConstrainedSleepEvolutionCause) -> T {
        do throws(CollisionError) { try work.collision.requireStorage(1);try work.collision.charge(1) } catch { throw .hybrid(.collision(error)) }
        let known=work.collision
        let output:T
        do throws(HybridError) { output=try body(&work.collision) }
        catch { if !valid(work.collision,known) { work.collision=known;work.failedSupplierWorkUnavailable=true;throw .supplierLedgerFailure(.hybrid(error)) };work.failedSupplierWorkUnavailable=true;throw .hybrid(error) }
        guard valid(work.collision,known),work.collision.operations > known.operations else { work.collision=known;work.failedSupplierWorkUnavailable=true;throw .supplierLedgerFailure(nil) };return output
    }
    static func valid(_ x:CollisionWork,_ k:CollisionWork) -> Bool { x.budget == k.budget && x.operations>=k.operations && x.iterations>=k.iterations && x.peakScalarStorage>=k.peakScalarStorage && x.operations<=x.budget.operations && x.iterations<=x.budget.iterations && x.peakScalarStorage<=x.budget.scalarStorage }
    static func valid(_ x:NumericalWork,_ k:NumericalWork) -> Bool { x.budget == k.budget && x.operations>=k.operations && x.iterations>=k.iterations && x.peakScalarStorage>=k.peakScalarStorage && x.operations<=x.budget.arithmeticOperations && x.iterations<=x.budget.iterations && x.peakScalarStorage<=x.budget.scalarStorage }
    static func valid(_ x:LoadWork,_ k:LoadWork) -> Bool { x.budget.maximumWork == k.budget.maximumWork && x.budget.maximumScalars == k.budget.maximumScalars && x.consumed>=k.consumed && x.peakScalars>=k.peakScalars && x.consumed<=x.budget.maximumWork && x.peakScalars<=x.budget.maximumScalars }
    static func valid(_ x:ContactWork,_ k:ContactWork) -> Bool { x.budget.operations == k.budget.operations && x.budget.scalarStorage == k.budget.scalarStorage && x.budget.records == k.budget.records && x.operations>=k.operations && x.peakScalarStorage>=k.peakScalarStorage && x.operations<=x.budget.operations && x.peakScalarStorage<=x.budget.scalarStorage }
}
