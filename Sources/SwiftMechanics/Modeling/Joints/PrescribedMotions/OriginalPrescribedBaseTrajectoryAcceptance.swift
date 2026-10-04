public enum OriginalPrescribedBaseTrajectoryAcceptance {
    @inline(never)
    public static func validated(_ supplied:PrescribedBaseMotionSample,program:PrescribedBaseTrajectoryProgram,time:Double,
                                 policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        let context=try prepare(program,time:time,policy:policy,work:&work)
        return try accept(supplied,context:context,policy:policy)
    }
    @inline(never)
    public static func sealedBaseMotion(_ program:PrescribedBaseTrajectoryProgram,time:Double,policy:PrescribedTrajectoryPolicy,
                                        sampler:any PrescribedBaseTrajectorySampling,work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        let context=try prepare(program,time:time,policy:policy,work:&work)
        let supplied=try TrajectorySupplierLedger.invoke(policy:policy,reservedStorage:context.reservedStorage,work:&work) {
            (ledger:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample in
            try sampler.sampleBase(program,time:time,policy:policy,work:&ledger)
        }
        return try accept(supplied,context:context,policy:policy)
    }
    @inline(never)
    private static func prepare(_ program:PrescribedBaseTrajectoryProgram,time:Double,policy:PrescribedTrajectoryPolicy,
                                work:inout NumericalWork) throws(PrescribedMotionError) -> TrajectoryOriginalContext<PrescribedBaseMotionSample> {
        let original=try AnalyticPrescribedBaseTrajectorySampler().sampleBase(program,time:time,policy:policy,work:&work)
        let reserve=try TrajectorySupplierLedger.reserve(metadataBytes:program.metadata.utf8.count,count:1,work:&work)
        return TrajectoryOriginalContext(original:original,reservedStorage:reserve)
    }
    private static func accept(_ supplied:PrescribedBaseMotionSample,context:TrajectoryOriginalContext<PrescribedBaseMotionSample>,
                               policy:PrescribedTrajectoryPolicy) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        guard supplied.metadata.utf8.count <= policy.motion.maximumMetadataBytes,supplied.frame.key.utf8.count <= policy.motion.maximumIdentifierBytes,
              supplied.worldFrame.key.utf8.count <= policy.motion.maximumIdentifierBytes else { throw .capacityExceeded }
        guard PrescribedBaseSampleComparison.matches(supplied,context.original) else { throw .staleSource }
        try PrescribedBaseMotionArithmetic.check(policy.motion);return context.original
    }
}
