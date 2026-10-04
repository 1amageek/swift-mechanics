public enum OriginalPrescribedTrajectoryAcceptance {
    @inline(never)
    public static func validated(_ supplied:PrescribedMotionSample,program:PrescribedTrajectoryProgram,time:Double,
                                 policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample {
        let context=try prepare(program,time:time,policy:policy,work:&work)
        return try accept(supplied,context:context,policy:policy)
    }
    @inline(never)
    public static func sealedMotion(_ program:PrescribedTrajectoryProgram,time:Double,policy:PrescribedTrajectoryPolicy,
                                    sampler:any PrescribedTrajectorySampling,work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample {
        let context=try prepare(program,time:time,policy:policy,work:&work)
        let supplied=try TrajectorySupplierLedger.invoke(policy:policy,reservedStorage:context.reservedStorage,work:&work) {
            (ledger:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample in
            try sampler.sample(program,time:time,policy:policy,work:&ledger)
        }
        return try accept(supplied,context:context,policy:policy)
    }
    @inline(never)
    private static func prepare(_ program:PrescribedTrajectoryProgram,time:Double,policy:PrescribedTrajectoryPolicy,
                                work:inout NumericalWork) throws(PrescribedMotionError) -> TrajectoryOriginalContext<PrescribedMotionSample> {
        let original=try AnalyticPrescribedTrajectorySampler().sample(program,time:time,policy:policy,work:&work)
        let reserve=try TrajectorySupplierLedger.reserve(metadataBytes:program.metadata.utf8.count,count:program.trajectories.count,work:&work)
        return TrajectoryOriginalContext(original:original,reservedStorage:reserve)
    }
    private static func accept(_ supplied:PrescribedMotionSample,context:TrajectoryOriginalContext<PrescribedMotionSample>,
                               policy:PrescribedTrajectoryPolicy) throws(PrescribedMotionError) -> PrescribedMotionSample {
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        guard supplied.metadata.utf8.count <= policy.motion.maximumMetadataBytes,supplied.anchors.count <= policy.motion.maximumSamples else { throw .capacityExceeded }
        for anchor in supplied.anchors { guard anchor.frame.key.utf8.count <= policy.motion.maximumIdentifierBytes else { throw .capacityExceeded } }
        let original=context.original
        guard supplied.metadata == original.metadata,supplied.time.bitPattern == original.time.bitPattern,
              OriginalPrescribedMotionAcceptance.matches(supplied.anchors,original.anchors) else { throw .staleSource }
        try PrescribedBaseMotionArithmetic.check(policy.motion);return original
    }
}
