internal enum TrajectorySupplierLedger {
    @inline(never)
    static func invoke<Value:Sendable>(policy:PrescribedTrajectoryPolicy,reservedStorage:Int,work:inout NumericalWork,
                                      body:(inout NumericalWork) throws(PrescribedMotionError) -> Value) throws(PrescribedMotionError) -> Value {
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        var local:NumericalWork
        do throws(NumericalError) {
            try work.chargeOperations(1)
            local=NumericalWork(budget:try work.remainingBudget(reservedStorage:reservedStorage));try local.chargeOperations(1)
        } catch { throw .numerical(error) }
        let before=local;var result:Value?,failure:PrescribedMotionError?
        do throws(PrescribedMotionError) { result = .some(try body(&local)) } catch { failure=error }
        let preserved=local.budget == before.budget && local.operations >= before.operations &&
            local.iterations >= before.iterations && local.peakScalarStorage >= before.peakScalarStorage
        do throws(NumericalError) { try work.absorb(preserved ? local : before,reservedStorage:reservedStorage) }
        catch { throw .numerical(error) }
        guard preserved else { throw .supplierLedgerReplaced }
        if let failure { throw failure }
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        guard let result else { throw .supplierWorkUnavailable };return result
    }
    static func reserve(metadataBytes:Int,count:Int,work:inout NumericalWork) throws(PrescribedMotionError) -> Int {
        let storage=try PrescribedTrajectoryArithmetic.sum(512,try PrescribedTrajectoryArithmetic.sum(metadataBytes/8+1,try PrescribedTrajectoryArithmetic.product(128,count)))
        let operations=try PrescribedTrajectoryArithmetic.sum(metadataBytes,try PrescribedTrajectoryArithmetic.product(256,count))
        try PrescribedBaseMotionArithmetic.reserve(storage,operations:operations,work:&work);return storage
    }
}
