internal enum ConstrainedImpactInvocation {
    static func valid(_ value: NumericalWork, after known: NumericalWork) -> Bool {
        value.budget == known.budget && value.operations >= known.operations && value.iterations >= known.iterations &&
        value.peakScalarStorage >= known.peakScalarStorage
    }
    private static func refused(_ failure: ConstrainedImpactError?) -> ConstrainedImpactError {
        if let failure, ConstrainedImpactArithmetic.isCancelled(failure.reason) {
            return ConstrainedImpactError(failure.reason, supplierFailure: failure.supplierFailure,
                                          failedSupplierWorkUnavailable: true)
        }
        return ConstrainedImpactError(.supplierLedgerFailure, supplierFailure: failure?.reason,
                                      failedSupplierWorkUnavailable: true)
    }
    @inline(never)
    static func numerical<T>(work: inout NumericalWork,
        _ body: (inout NumericalWork) throws(ConstrainedImpactError) -> T) throws(ConstrainedImpactError) -> T {
        try ConstrainedImpactArithmetic.storage(max(1,work.peakScalarStorage),&work)
        try ConstrainedImpactArithmetic.charge(1,&work)
        let known = work
        let value: T
        do { value = try body(&work) }
        catch {
            guard valid(work,after:known) else { work = known; throw refused(error) }
            throw error
        }
        guard valid(work,after:known) else { work = known; throw refused(nil) }
        return value
    }
    @inline(never)
    static func assembly<T>(load: inout LoadWork, work: inout NumericalWork,
        _ body: (inout LoadWork,inout NumericalWork) throws(ConstrainedImpactError) -> T) throws(ConstrainedImpactError) -> T {
        do { try load.reserve(scalars:max(1,load.peakScalars)); try load.charge(1) }
        catch { throw ConstrainedImpactError(.load(error)) }
        try ConstrainedImpactArithmetic.storage(max(1,work.peakScalarStorage),&work)
        try ConstrainedImpactArithmetic.charge(1,&work)
        let knownLoad = load, knownWork = work
        let value: T
        do { value = try body(&load,&work) }
        catch {
            let loadValid = valid(load,after:knownLoad), numericalValid = valid(work,after:knownWork)
            if !loadValid { load = knownLoad }
            if !numericalValid { work = knownWork }
            guard loadValid && numericalValid else { throw refused(error) }
            try restoreLoadBudget(&load,known:knownLoad)
            throw error
        }
        let loadValid = valid(load,after:knownLoad), numericalValid = valid(work,after:knownWork)
        if !loadValid { load = knownLoad }
        if !numericalValid { work = knownWork }
        guard loadValid && numericalValid else { throw refused(nil) }
        try restoreLoadBudget(&load,known:knownLoad)
        return value
    }
    private static func valid(_ value: LoadWork, after known: LoadWork) -> Bool {
        value.budget.maximumWork == known.budget.maximumWork && value.budget.maximumScalars == known.budget.maximumScalars &&
        value.consumed >= known.consumed && value.peakScalars >= known.peakScalars
    }
    private static func restoreLoadBudget(_ value: inout LoadWork, known: LoadWork) throws(ConstrainedImpactError) {
        // Keep the original cancellation closure; limits alone do not establish closure identity.
        var restored = known
        do { try restored.charge(value.consumed-known.consumed); try restored.reserve(scalars:value.peakScalars) }
        catch { value = restored; throw ConstrainedImpactError(.load(error)) }
        value = restored
    }
    @inline(never)
    static func contact<T>(work: inout ContactWork,
        _ body: (inout ContactWork) throws(ConstrainedImpactError) -> T) throws(ConstrainedImpactError) -> T {
        do { try work.consume(operations:1,scalarStorage:max(1,work.peakScalarStorage),records:1) }
        catch { throw ConstrainedImpactError(.contact(error)) }
        let known = work
        let value: T
        do { value = try body(&work) }
        catch {
            guard valid(work,after:known) else { work = known; throw refused(error) }
            throw error
        }
        guard valid(work,after:known) else { work = known; throw refused(nil) }
        return value
    }
    private static func valid(_ value: ContactWork, after known: ContactWork) -> Bool {
        value.budget.operations == known.budget.operations && value.budget.scalarStorage == known.budget.scalarStorage &&
        value.budget.records == known.budget.records && value.operations >= known.operations &&
        value.peakScalarStorage >= known.peakScalarStorage
    }
    static func local(_ work: NumericalWork, reserved: Int) throws(ConstrainedImpactError) -> NumericalWork {
        let budget = try ConstrainedImpactArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        return NumericalWork(budget:budget)
    }
    static func absorb(_ value: NumericalWork, into work: inout NumericalWork, reserved: Int) throws(ConstrainedImpactError) {
        try ConstrainedImpactArithmetic.numerical { () throws(NumericalError) in try work.absorb(value,reservedStorage:reserved) }
    }
}
