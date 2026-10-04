internal enum IdentificationArithmetic {
    static func check(_ p:IdentificationPolicy) throws(IdentificationCause) {
        guard !p.isCancelled(), !Task.isCancelled else { throw .cancelled }
    }
    static func charge(_ count:Int,_ p:IdentificationPolicy,_ w:inout NumericalWork) throws(IdentificationCause) {
        try check(p)
        do { try w.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func finite(_ x:Double) throws(IdentificationCause) -> Double {
        guard x.isFinite else { throw .nonFiniteResult }; return x
    }
    static func sum(_ a:Int,_ b:Int) throws(IdentificationCause) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
    static func product(_ a:Int,_ b:Int) throws(IdentificationCause) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) }
    }
    static func core<Value>(_ call:() throws(CoreError) -> Value) throws(IdentificationCause) -> Value {
        do { return try call() } catch { throw .core(error) }
    }
    static func agrees(_ a:Double,_ b:Double,_ tolerance:NumericalTolerance) throws(IdentificationCause) -> Bool {
        try core { () throws(CoreError) in try tolerance.contains(error:a-b,scale:max(abs(a),abs(b))) }
    }
    static func key(_ key:String,_ p:IdentificationPolicy,_ c:inout IdentificationContext,_ w:inout NumericalWork) throws(IdentificationCause) {
        for _ in key.utf8 {
            guard c.metadataBytes < p.maximumMetadataBytes else { throw .capacity }
            try charge(2,p,&w); c.metadataBytes += 1
        }
    }
    static func id(_ id:EntityID,_ p:IdentificationPolicy,_ c:inout IdentificationContext,_ w:inout NumericalWork) throws(IdentificationCause) {
        try key(id.key,p,&c,&w)
    }
    static func nested(_ w:NumericalWork,reserved:Int) throws(IdentificationCause) -> NumericalWork {
        do {
            var child=NumericalWork(budget:try w.remainingBudget(reservedStorage:reserved))
            try child.chargeOperations(1)
            return child
        } catch { throw .numerical(error) }
    }
    static func ledger(_ child:NumericalWork,_ before:NumericalWork,reserved:Int,_ c:inout IdentificationContext,_ w:inout NumericalWork) throws(IdentificationCause) {
        guard child.budget == before.budget, child.operations >= before.operations,
              child.iterations >= before.iterations, child.peakScalarStorage >= before.peakScalarStorage else {
            c.unavailable=true
            try absorb(before,reserved:reserved,&w)
            throw .invalidSupplierLedger
        }
    }
    static func absorb(_ child:NumericalWork,reserved:Int,_ w:inout NumericalWork) throws(IdentificationCause) {
        do { try w.absorb(child,reservedStorage:reserved) } catch { throw .numerical(error) }
    }
}
