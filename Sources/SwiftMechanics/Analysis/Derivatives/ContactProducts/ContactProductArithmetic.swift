internal enum ContactProductArithmetic {
    static func check(_ policy: ContactDerivativePolicy) throws(ContactDerivativeError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func charge(_ count: Int, _ work: inout ContactDerivativeWork, storage: Int = 256) throws(ContactDerivativeError) {
        try work.consume(operations:count,scalarStorage:storage,records:1)
    }
    static func finite(_ value: Double) throws(ContactDerivativeError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    static func core<T>(_ operation: () throws(CoreError) -> T) throws(ContactDerivativeError) -> T {
        do { return try operation() } catch { throw .core(error) }
    }
    static func equal(_ a: Double, _ b: Double, _ policy: ContactDerivativePolicy) throws(ContactDerivativeError) {
        let delta=try finite(a-b), bound=try finite(policy.absolutePrimalTolerance+policy.relativePrimalTolerance*max(abs(a),abs(b)))
        guard abs(delta) <= bound else { throw .primalMismatch }
    }
    static func metadata(_ pair: ContactLawPair, identity: ContactIdentity?, policy: ContactDerivativePolicy,
                         work: inout ContactDerivativeWork) throws(ContactDerivativeError) {
        try check(policy); try charge(32,&work)
        var remaining=policy.maximumIdentifierBytes
        func key(_ text: String, _ work: inout ContactDerivativeWork) throws(ContactDerivativeError) {
            for _ in text.utf8 {
                try check(policy); guard remaining > 0 else { throw .law(.resourceLimit(resource:.scalarStorage,limit:policy.maximumIdentifierBytes)) }
                remaining -= 1; try charge(1,&work)
            }
        }
        try key(pair.firstMaterial.id.key,&work); try key(pair.secondMaterial.id.key,&work)
        if let identity {
            // FIXME(INCOMPLETE_IMPLEMENTATION): Material-site derivative provenance is not implemented.
            // ContactProducts currently rejects such calls; original site-aware acceptance is required before success.
            guard identity.firstMaterialSite == nil else { throw .unsupportedDomain }
            try key(identity.key,&work); try key(identity.firstBody.id.key,&work)
            try key(identity.secondBody.id.key,&work); try key(identity.frame.id.key,&work)
        }
    }
    static func supplier<T>(_ policy: ContactDerivativePolicy, work: inout ContactDerivativeWork,
                            operation: (inout ContactWork) throws(ContactLawError) -> T) throws(ContactDerivativeError) -> T {
        try check(policy); try charge(1,&work)
        let budget: ContactBudget
        do { budget=try ContactBudget(operations:work.budget.operations-work.operations,scalarStorage:work.budget.scalarStorage,records:work.budget.records) }
        catch { throw .law(error) }
        var local=ContactWork(budget:budget)
        do { try local.consume(operations:1,scalarStorage:0,records:0) } catch { throw .law(error) }
        let result: Result<T,ContactLawError>
        do { result = .success(try operation(&local)) } catch { result = .failure(error) }
        guard local.budget.operations == budget.operations, local.budget.scalarStorage == budget.scalarStorage,
              local.budget.records == budget.records, local.operations >= 1, local.operations <= budget.operations,
              local.peakScalarStorage <= budget.scalarStorage else { throw .invalidSupplierLedger(failedSupplierWorkUnavailable:true) }
        try work.absorb(operations:local.operations,scalarStorage:local.peakScalarStorage,records:0)
        try check(policy)
        switch result { case .success(let value): return value; case .failure(let error): throw .law(error) }
    }
}
