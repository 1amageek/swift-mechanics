internal enum ToothArithmetic {
    static func check(_ policy: ToothContactPolicy) throws(ToothContactError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func finite(_ value: Double) throws(ToothContactError) {
        guard value.isFinite else { throw .nonFiniteResult }
    }
    static func value(_ value: Double) throws(ToothContactError) -> Double { try finite(value); return value }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(ToothContactError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    static func product(_ a: Int,_ b: Int) throws(ToothContactError) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) }
    }
    static func sum(_ a: Int,_ b: Int) throws(ToothContactError) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
    static func slots(teeth: Int, contacts: Int) throws(ToothContactError) -> Int {
        try sum(512,sum(product(128,teeth),product(512,contacts)))
    }
    static func close(_ a: Double,_ b: Double, scale: Double = 1, policy: ToothContactPolicy) throws(ToothContactError) {
        guard scale.isFinite, scale > 0 else { throw .invalidInput }
        let error=try value(abs(a-b)/scale)
        guard error <= policy.physicalTolerance else { throw .originalResidual(value:error,threshold:policy.physicalTolerance) }
    }
    static func vector(_ a: Vector3,_ b: Vector3, policy: ToothContactPolicy) throws(ToothContactError) {
        let error=try core { () throws(CoreError) in try a.subtracting(b).magnitude() }
        guard error <= policy.collision.lengthTolerance else { throw .invalidSupplierOutput }
    }
    static func key(_ key: String, remaining: inout Int, policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) {
        for _ in key.utf8 {
            try check(policy); guard remaining > 0 else { throw .capacityExceeded }
            try work.charge(1); remaining -= 1
        }
    }
    static func numeric<T>(reserved: Int, policy: ToothContactPolicy, work: inout ToothContactWork,
                           operation: (inout NumericalWork) throws(DynamicsError) -> T) throws(ToothContactError) -> T {
        try check(policy); try work.beginCall()
        let budget: NumericalBudget
        do { budget=try NumericalBudget(scalarStorage:work.budget.scalarStorage-reserved,
            arithmeticOperations:work.budget.arithmeticOperations-work.operations,iterations:work.budget.iterations-work.iterations) }
        catch { throw .numerical(error) }
        var local=NumericalWork(budget:budget)
        do { try local.chargeOperations(1); try local.advanceIteration() } catch {
            try work.charge(local.operations,storage:sum(reserved,local.peakScalarStorage),iterations:local.iterations)
            throw .numerical(error)
        }
        let result: Result<T,DynamicsError>
        do { result = .success(try operation(&local)) } catch { result = .failure(error) }
        guard local.budget == budget, local.operations >= 1, local.iterations >= 1,
              local.operations <= budget.arithmeticOperations, local.iterations <= budget.iterations,
              local.peakScalarStorage <= budget.scalarStorage else {
            // The opaque ledger cannot erase the independently executed local seed.
            try work.charge(1,storage:reserved,iterations:1)
            throw .invalidSupplierLedger(failedSupplierWorkUnavailable:true)
        }
        try work.charge(local.operations,storage:sum(reserved,local.peakScalarStorage),iterations:local.iterations)
        try check(policy)
        switch result { case .success(let value): return value; case .failure(let e): throw .dynamics(e) }
    }
    static func collision<T>(reserved: Int, policy: ToothContactPolicy, work: inout ToothContactWork,
                             operation: (inout CollisionWork) throws(CollisionError) -> T) throws(ToothContactError) -> T {
        try check(policy); try work.beginCall()
        let budget: CollisionBudget
        do { budget=try CollisionBudget(scalarStorage:work.budget.scalarStorage-reserved,operations:work.budget.arithmeticOperations-work.operations,
            iterations:work.budget.iterations-work.iterations,records:1) } catch { throw .collision(error) }
        var local=CollisionWork(budget:budget)
        do { try local.charge(1); try local.advanceIteration() } catch {
            try work.charge(local.operations,storage:sum(reserved,local.peakScalarStorage),iterations:local.iterations)
            throw .collision(error)
        }
        let result: Result<T,CollisionError>
        do { result = .success(try operation(&local)) } catch { result = .failure(error) }
        guard local.budget == budget, local.operations >= 1, local.iterations >= 1,
              local.operations <= budget.operations, local.iterations <= budget.iterations,
              local.peakScalarStorage <= budget.scalarStorage else {
            // The opaque ledger cannot erase the independently executed local seed.
            try work.charge(1,storage:reserved,iterations:1)
            throw .invalidSupplierLedger(failedSupplierWorkUnavailable:true)
        }
        try work.charge(local.operations,storage:sum(reserved,local.peakScalarStorage),iterations:local.iterations)
        try check(policy)
        switch result { case .success(let value): return value; case .failure(let e): throw .collision(e) }
    }
    static func contact<T>(reserved: Int, policy: ToothContactPolicy, work: inout ToothContactWork,
                           operation: (inout ContactWork) throws(ContactLawError) -> T) throws(ToothContactError) -> T {
        try check(policy); try work.beginCall()
        let budget: ContactBudget
        do { budget=try ContactBudget(operations:work.budget.arithmeticOperations-work.operations,scalarStorage:work.budget.scalarStorage-reserved,records:1) }
        catch { throw .contact(error) }
        var local=ContactWork(budget:budget)
        do { try local.consume(operations:1,scalarStorage:0,records:0) } catch {
            try work.charge(local.operations,storage:sum(reserved,local.peakScalarStorage))
            throw .contact(error)
        }
        let result: Result<T,ContactLawError>
        do { result = .success(try operation(&local)) } catch { result = .failure(error) }
        guard local.budget.operations == budget.operations, local.budget.scalarStorage == budget.scalarStorage,
              local.budget.records == budget.records, local.operations >= 1, local.operations <= budget.operations,
              local.peakScalarStorage <= budget.scalarStorage else {
            // The contact seed has no iteration cost.
            try work.charge(1,storage:reserved)
            throw .invalidSupplierLedger(failedSupplierWorkUnavailable:true)
        }
        try work.charge(local.operations,storage:sum(reserved,local.peakScalarStorage))
        try check(policy)
        switch result { case .success(let value): return value; case .failure(let e): throw .contact(e) }
    }
    static func current<T>(reserved: Int, policy: ToothContactPolicy, work: inout ToothContactWork,
                           operation: (inout ContactWork) throws(ContactCurrentError) -> T) throws(ToothContactError) -> T {
        try check(policy); try work.beginCall()
        let budget: ContactBudget
        do { budget=try ContactBudget(operations:work.budget.arithmeticOperations-work.operations,scalarStorage:work.budget.scalarStorage-reserved,records:1) }
        catch { throw .contact(error) }
        var local=ContactWork(budget:budget)
        do { try local.consume(operations:1,scalarStorage:0,records:0) } catch {
            try work.charge(local.operations,storage:sum(reserved,local.peakScalarStorage))
            throw .contact(error)
        }
        let result: Result<T,ContactCurrentError>
        do { result = .success(try operation(&local)) } catch { result = .failure(error) }
        guard local.budget.operations == budget.operations, local.budget.scalarStorage == budget.scalarStorage,
              local.budget.records == budget.records, local.operations >= 1, local.operations <= budget.operations,
              local.peakScalarStorage <= budget.scalarStorage else {
            // The contact seed has no iteration cost.
            try work.charge(1,storage:reserved)
            throw .invalidSupplierLedger(failedSupplierWorkUnavailable:true)
        }
        try work.charge(local.operations,storage:sum(reserved,local.peakScalarStorage))
        try check(policy)
        switch result { case .success(let value): return value; case .failure(let e): throw .current(e) }
    }
    @inline(never)
    static func snapshot(_ model: ToothContactModel, state: KinematicState, policy: ToothContactPolicy,
                         work: inout ToothContactWork) throws(ToothContactError) -> KinematicSnapshot {
        try check(policy); try work.charge(4096,storage:slots(teeth:model.teeth.count,contacts:model.contacts.count))
        do { return try TreeKinematicsEvaluator().evaluate(model.tree,state:state,policy:model.jointPolicy) }
        catch let error as JointError { throw .joint(error) }
        catch let error as CoreError { throw .core(error) }
        catch { throw .unexpectedKinematicsFailure }
    }
}
