/// Immutable new-family sampling and canonical smooth-boundary authority.
internal final class GeometricTrajectoryAuthority: Sendable {
    let anchors:PrescribedTrajectoryProgram?
    let base:PrescribedBaseTrajectoryProgram?
    private let sampler:(any PrescribedTrajectorySampling)?
    private let baseSampler:(any PrescribedBaseTrajectorySampling)?
    private let query:any PrescribedTrajectoryBoundaryQuerying
    init(anchors:PrescribedTrajectoryProgram,sampler:any PrescribedTrajectorySampling,query:any PrescribedTrajectoryBoundaryQuerying) {
        self.anchors=anchors;base=nil;self.sampler=sampler;baseSampler=nil;self.query=query
    }
    init(base:PrescribedBaseTrajectoryProgram,sampler:any PrescribedBaseTrajectorySampling,query:any PrescribedTrajectoryBoundaryQuerying) {
        anchors=nil;self.base=base;self.sampler=nil;baseSampler=sampler;self.query=query
    }
    @inline(never)
    func anchorSample(time:Double,work:inout NumericalWork) throws(PrescribedMotionError) -> [PrescribedAnchorState] {
        guard let anchors,let sampler else { return [] }
        return try OriginalPrescribedTrajectoryAcceptance.sealedMotion(anchors,time:time,policy:anchors.policy,sampler:sampler,work:&work).anchors
    }
    @inline(never)
    func baseSample(time:Double,work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample? {
        guard let base,let baseSampler else { return nil }
        return try OriginalPrescribedBaseTrajectoryAcceptance.sealedBaseMotion(base,time:time,policy:base.policy,sampler:baseSampler,work:&work)
    }
    @inline(never)
    func nextBoundary(after time:Double,through limit:Double,work:inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        if let base {
            return try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBaseBoundary(base,after:time,through:limit,policy:base.policy,query:query,work:&work)
        }
        guard let anchors else { throw .staleSource }
        return try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBoundary(anchors,after:time,through:limit,policy:anchors.policy,query:query,work:&work)
    }
}
