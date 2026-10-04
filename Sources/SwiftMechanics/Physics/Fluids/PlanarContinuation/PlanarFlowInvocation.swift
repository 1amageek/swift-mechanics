internal final class PlanarFlowInvocation: Sendable {
    let result: PlanarStepResult

    @inline(never)
    private init(flow: any PlanarFlowOperating, state: PlanarState, source: PlanarSource,
                 duration: Double, policy: PlanarPolicy, work: inout NumericalWork) throws(PlanarFluidError) {
        result = try flow.step(state: state, source: source, duration: duration, policy: policy, work: &work)
    }

    @inline(never)
    static func invoke(flow: any PlanarFlowOperating, state: PlanarState, source: PlanarSource,
                       duration: Double, policy: PlanarPolicy, work: inout NumericalWork) throws(PlanarContinuationError) -> PlanarFlowInvocation {
        // The boundary marker makes a fresh same-budget reset observable for an empty caller ledger.
        do throws(NumericalError) { try work.chargeOperations(1) }
        catch { throw .physical(.numerical(error, failedSupplierWorkUnavailable: false)) }
        let known = work
        var produced: PlanarFlowInvocation?, failure: PlanarFluidError?
        do throws(PlanarFluidError) {
            produced = try PlanarFlowInvocation(flow: flow, state: state, source: source,
                duration: duration, policy: policy, work: &work)
        } catch { failure = error }
        // Check both successful and failed suppliers before consuming their result or failure.
        guard work.budget == known.budget, work.operations >= known.operations,
              work.iterations >= known.iterations, work.peakScalarStorage >= known.peakScalarStorage else {
            work = known
            throw .supplierLedgerFailure
        }
        if let failure { throw .physical(failure) }
        guard let produced, work.operations > known.operations, work.iterations > known.iterations,
              work.peakScalarStorage > 0 else {
            work = known
            throw .supplierLedgerFailure
        }
        return produced
    }
}
