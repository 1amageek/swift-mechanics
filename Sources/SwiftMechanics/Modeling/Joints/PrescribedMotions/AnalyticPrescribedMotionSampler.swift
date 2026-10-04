public struct AnalyticPrescribedMotionSampler: PrescribedMotionSampling {
    public init() {}
    public func sample(_ program:PrescribedMotionProgram,time:Double,policy:PrescribedMotionPolicy,
                       work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample {
        guard program.motions.count <= policy.maximumSamples,program.metadata.utf8.count <= policy.maximumMetadataBytes else { throw .capacityExceeded }
        if policy.isCancelled() { throw .cancelled }
        guard time.isFinite else { throw .invalidInput }
        do throws(NumericalError) { try work.requireStorage(try NumericalWork.product(128,program.motions.count));try work.chargeOperations(try NumericalWork.sum(program.metadata.utf8.count,try NumericalWork.product(512,program.motions.count))) }
        catch { throw .numerical(error) }
        var anchors:[PrescribedAnchorState]=[];anchors.reserveCapacity(program.motions.count)
        for m in program.motions {
            guard m.frame.key.utf8.count <= policy.maximumIdentifierBytes,m.parentFrame.key.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded }
            let motion=try AnalyticMotionEvaluation.motion(m,time:time)
            do throws(JointError) { anchors.append(try PrescribedAnchorState(frame:m.frame,time:time,motion:motion)) }
            catch { throw .invalidInput }
        }
        if policy.isCancelled() { throw .cancelled }
        return try PrescribedMotionSample(metadata:program.metadata,time:time,anchors:anchors,policy:policy)
    }
}
