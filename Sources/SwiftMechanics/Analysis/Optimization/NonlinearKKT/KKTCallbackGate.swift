internal enum KKTCallbackGate {
    @inline(never)
    static func invoke<Scalar: NumericalScalar>(_ provider: any SmoothNonlinearProgramProviding<Scalar>,layout: NonlinearProgramLayout,
        scratch: Int,cancelled: @Sendable () -> Bool,work: inout NumericalWork,
        body: (inout NumericalWork) throws(NonlinearCause) -> Void) throws(NonlinearCause) {
        try KKTArithmetic.check(cancelled)
        guard provider.layout === layout else { throw .equationMetadataChanged }
        let budget: NumericalBudget
        do { budget=try NumericalBudget(scalarStorage:scratch,arithmeticOperations:work.budget.arithmeticOperations-work.operations,iterations:work.budget.iterations-work.iterations) }
        catch { throw .numerical(error) }
        var callback=NumericalWork(budget:budget)
        do { try callback.chargeOperations(1) } catch { throw .numerical(error) }
        var failure: NonlinearCause?
        do { try body(&callback) } catch { failure=error }
        guard callback.budget == budget, callback.operations >= 1 else { throw .equation(.evaluationFailed(code:KKTArithmetic.invalidLedgerCode)) }
        // Storage for the maximum callback scratch is already in the outer owner's reservation.
        do { try work.absorb(callback,reservedStorage:0) } catch { throw .numerical(error) }
        guard provider.layout === layout else { throw .equationMetadataChanged }
        if let failure { throw failure }
        try KKTArithmetic.check(cancelled)
    }
}
