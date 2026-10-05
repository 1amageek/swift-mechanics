internal enum IslandInvocation {
    static func valid(_ value: NumericalWork, _ known: NumericalWork) -> Bool {
        value.budget == known.budget && value.operations >= known.operations && value.iterations >= known.iterations &&
        value.peakScalarStorage >= known.peakScalarStorage
    }
    @inline(never)
    static func numerical<T>(_ work: inout NumericalWork,
        _ body: (inout NumericalWork) throws(StationaryIslandFailureReason) -> T) throws(StationaryIslandFailureReason) -> T {
        try IslandArithmetic.storage(max(1,work.peakScalarStorage),&work);try IslandArithmetic.charge(1,&work)
        let known=work
        do throws(StationaryIslandFailureReason) {
            let result=try body(&work)
            guard valid(work,known) else { work=known;throw .supplierLedgerFailure(nil) };return result
        } catch {
            guard valid(work,known) else { work=known;throw .supplierLedgerFailure(error) }
            throw error
        }
    }
    @inline(never)
    static func assembly<T>(_ work: inout StationaryIslandWork,
        _ body: (inout LoadWork,inout NumericalWork) throws(StationaryIslandFailureReason) -> T) throws(StationaryIslandFailureReason) -> T {
        do throws(LoadError) { try work.loads.reserve(scalars:max(1,work.loads.peakScalars));try work.loads.charge(1) }
        catch { throw .load(error) }
        try IslandArithmetic.storage(max(1,work.numerical.peakScalarStorage),&work.numerical);try IslandArithmetic.charge(1,&work.numerical)
        let knownLoad=work.loads, knownNumerical=work.numerical
        var result:T?, failure:StationaryIslandFailureReason?
        do { result=try body(&work.loads,&work.numerical) } catch { failure=error }
        let loadValid=work.loads.budget.maximumWork == knownLoad.budget.maximumWork && work.loads.budget.maximumScalars == knownLoad.budget.maximumScalars &&
            work.loads.consumed >= knownLoad.consumed && work.loads.peakScalars >= knownLoad.peakScalars
        let numericalValid=valid(work.numerical,knownNumerical)
        if !loadValid { work.loads=knownLoad };if !numericalValid { work.numerical=knownNumerical }
        guard loadValid && numericalValid else { work.unavailable();throw .supplierLedgerFailure(failure) }
        var original=knownLoad
        do throws(LoadError) { try original.charge(work.loads.consumed-knownLoad.consumed);try original.reserve(scalars:work.loads.peakScalars) }
        catch { work.loads=knownLoad;work.unavailable();throw .supplierLedgerFailure(failure ?? .load(error)) }
        work.loads=original
        if let failure { throw failure }
        guard let result else { throw .invalidInput };return result
    }
    @inline(never)
    static func local<T>(work: inout NumericalWork, reserved: Int,
        _ body: (inout NumericalWork) throws(StationaryIslandFailureReason) -> T) throws(StationaryIslandFailureReason) -> T {
        let budget=try IslandArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        var local=NumericalWork(budget:budget)
        let value:T
        do { value=try numerical(&local,body) }
        catch { try IslandArithmetic.numerical { () throws(NumericalError) in try work.absorb(local,reservedStorage:reserved) };throw error }
        try IslandArithmetic.numerical { () throws(NumericalError) in try work.absorb(local,reservedStorage:reserved) }
        return value
    }
}
