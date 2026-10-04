internal enum GranularRuntimeInvocation {
    @inline(never)
    static func compare(evolution: any GranularEvolving,accepted: GranularState,canonical: GranularStepResult,
                        source: GranularRuntimeSource,choice: UInt64,
                        work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        try source.poll(work)
        let n=work.numerical,c=work.collision,l=work.contact,s=work.suppliers
        var workspace=GranularWorkspace(),result: GranularStepResult?,failure: GranularError?
        do throws(GranularError) {
            result=try evolution.step(accepted:accepted,timeStepSeconds:source.timeStepSeconds,
                gravity:source.gravityChoices[Int(choice)],policy:source.policy,workspace:&workspace,
                numericalWork:&work.numerical,collisionWork:&work.collision,contactWork:&work.contact,supplierWork:&work.suppliers)
        } catch { failure=error }
        let numericOK=work.numerical.budget == n.budget && work.numerical.operations >= n.operations &&
            work.numerical.iterations >= n.iterations && work.numerical.peakScalarStorage >= n.peakScalarStorage
        let collisionOK=work.collision.budget == c.budget && work.collision.operations >= c.operations &&
            work.collision.iterations >= c.iterations && work.collision.peakScalarStorage >= c.peakScalarStorage
        let contactOK=work.contact.budget.operations == l.budget.operations && work.contact.budget.scalarStorage == l.budget.scalarStorage &&
            work.contact.budget.records == l.budget.records && work.contact.operations >= l.operations && work.contact.peakScalarStorage >= l.peakScalarStorage
        let supplierOK=work.suppliers.maximumCalls == s.maximumCalls && work.suppliers.calls >= s.calls
        if !numericOK { work.numerical=n };if !collisionOK { work.collision=c };if !contactOK { work.contact=l };if !supplierOK { work.suppliers=s }
        guard numericOK,collisionOK,contactOK,supplierOK else { throw .supplierLedgerReplaced }
        if let failure { throw .physical(failure) }
        guard let result,work.numerical.operations > n.operations,work.collision.operations > c.operations,
              work.contact.operations > l.operations,work.suppliers.calls > s.calls else { throw .invalidSupplierEvidence }
        try work.charge(try GranularJournalWire.sum(32,GranularJournalWire.sum(GranularJournalWire.product(32,accepted.motions.count),GranularJournalWire.product(128,accepted.contacts.count))))
        guard GranularJournalWire.same(result.state,canonical.state) else { throw .invalidSupplierEvidence }
        try source.poll(work)
    }
}
