internal enum GranularRuntimeInvocation {
    @inline(never)
    static func compare(evolution: any GranularEvolving,input: GranularRuntimeStepInput,canonical: GranularRuntimeStepEvidence,
                        source: GranularRuntimeSource,work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        try source.poll(work)
        let prefix=GranularRuntimeSupplierPrefix(work)
        let outcome=invoke(evolution:evolution,input:input,source:source,work:&work)
        try acceptLedgers(prefix,outcome:outcome,work:&work)
        try acceptResult(outcome,input:input,canonical:canonical,work:&work)
        try source.poll(work)
    }
    @inline(never)
    private static func invoke(evolution: any GranularEvolving,input: GranularRuntimeStepInput,source: GranularRuntimeSource,
                               work: inout GranularRuntimeWork) -> GranularRuntimeSupplierOutcome {
        var workspace=GranularWorkspace()
        do throws(GranularError) {
            let result=try evolution.step(accepted:input.accepted.particles,timeStepSeconds:source.timeStepSeconds,
                gravity:source.gravityChoices[Int(input.choice)],policy:source.policy,workspace:&workspace,
                numericalWork:&work.numerical,collisionWork:&work.collision,contactWork:&work.contact,supplierWork:&work.suppliers)
            return GranularRuntimeSupplierOutcome(result:result,failure:nil)
        } catch { return GranularRuntimeSupplierOutcome(result:nil,failure:error) }
    }
    @inline(never)
    private static func acceptLedgers(_ prefix: GranularRuntimeSupplierPrefix,outcome: GranularRuntimeSupplierOutcome,
                                      work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        let n=prefix.numerical,c=prefix.collision,l=prefix.contact,s=prefix.suppliers
        let numericOK=work.numerical.budget == n.budget && work.numerical.operations >= n.operations &&
            work.numerical.iterations >= n.iterations && work.numerical.peakScalarStorage >= n.peakScalarStorage
        let collisionOK=work.collision.budget == c.budget && work.collision.operations >= c.operations &&
            work.collision.iterations >= c.iterations && work.collision.peakScalarStorage >= c.peakScalarStorage
        let contactOK=work.contact.budget.operations == l.budget.operations && work.contact.budget.scalarStorage == l.budget.scalarStorage &&
            work.contact.budget.records == l.budget.records && work.contact.operations >= l.operations && work.contact.peakScalarStorage >= l.peakScalarStorage
        let supplierOK=work.suppliers.maximumCalls == s.maximumCalls && work.suppliers.calls >= s.calls
        if !numericOK { work.numerical=n };if !collisionOK { work.collision=c };if !contactOK { work.contact=l };if !supplierOK { work.suppliers=s }
        guard numericOK,collisionOK,contactOK,supplierOK else { throw .supplierLedgerReplaced }
        if let failure=outcome.failure { throw .physical(failure) }
        guard outcome.result != nil,work.numerical.operations > n.operations,work.collision.operations > c.operations,
              work.contact.operations > l.operations,work.suppliers.calls > s.calls else { throw .invalidSupplierEvidence }
    }
    @inline(never)
    private static func acceptResult(_ outcome: GranularRuntimeSupplierOutcome,input: GranularRuntimeStepInput,
                                     canonical: GranularRuntimeStepEvidence,work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        guard let result=outcome.result else { throw .invalidSupplierEvidence }
        try work.charge(try GranularJournalWire.sum(32,GranularJournalWire.sum(GranularJournalWire.product(32,input.accepted.particles.motions.count),GranularJournalWire.product(128,input.accepted.particles.contacts.count))))
        guard GranularJournalWire.same(result.state,canonical.result.state) else { throw .invalidSupplierEvidence }
    }
}
