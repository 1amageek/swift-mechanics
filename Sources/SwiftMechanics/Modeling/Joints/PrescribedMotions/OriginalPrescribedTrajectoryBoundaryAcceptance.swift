public enum OriginalPrescribedTrajectoryBoundaryAcceptance {
    @inline(never)
    public static func nextBoundary(_ program:PrescribedTrajectoryProgram,after time:Double,through limit:Double,
                                    policy:PrescribedTrajectoryPolicy,query:any PrescribedTrajectoryBoundaryQuerying,
                                    work:inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        let original=try PrescribedTrajectoryBoundaryQuery().nextBoundary(program,after:time,through:limit,policy:policy,work:&work)
        let reserve=try TrajectorySupplierLedger.reserve(metadataBytes:program.metadata.utf8.count,count:program.trajectories.count,work:&work)
        let result=try TrajectorySupplierLedger.invoke(policy:policy,reservedStorage:reserve,work:&work) {
            (ledger:inout NumericalWork) throws(PrescribedMotionError) -> Double? in
            try query.nextBoundary(program,after:time,through:limit,policy:policy,work:&ledger)
        }
        guard result?.bitPattern == original?.bitPattern else { throw .staleSource }
        try PrescribedBaseMotionArithmetic.check(policy.motion);return original
    }
    @inline(never)
    public static func nextBaseBoundary(_ program:PrescribedBaseTrajectoryProgram,after time:Double,through limit:Double,
                                        policy:PrescribedTrajectoryPolicy,query:any PrescribedTrajectoryBoundaryQuerying,
                                        work:inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        let original=try PrescribedTrajectoryBoundaryQuery().nextBaseBoundary(program,after:time,through:limit,policy:policy,work:&work)
        let reserve=try TrajectorySupplierLedger.reserve(metadataBytes:program.metadata.utf8.count,count:1,work:&work)
        let result=try TrajectorySupplierLedger.invoke(policy:policy,reservedStorage:reserve,work:&work) {
            (ledger:inout NumericalWork) throws(PrescribedMotionError) -> Double? in
            try query.nextBaseBoundary(program,after:time,through:limit,policy:policy,work:&ledger)
        }
        guard result?.bitPattern == original?.bitPattern else { throw .staleSource }
        try PrescribedBaseMotionArithmetic.check(policy.motion);return original
    }
}
