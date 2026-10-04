@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct ReferenceNonlinearSubtreeAccelerationPreparer: NonlinearSubtreeAccelerationPreparing {
    public init() {}
    @inline(never)
    public func prepare(release:SubtreeRelease,equations:NonlinearMechanismEquation,work:inout NumericalWork) throws(RuntimeFailure) -> NonlinearReconciledSubtreeRelease {
        try equations.validate(model:release.target)
        let incoming=release.incomingPhysical
        let motion=try equations.coldReconciledMotion(incoming,work:&work)
        let physical:KinematicState
        do throws(JointError) {
            physical=try KinematicState(revision:incoming.revision,time:incoming.time,q:incoming.q,v:incoming.v,
                acceleration:motion.values,prescribedAnchors:incoming.prescribedAnchors)
        } catch { throw RuntimeFailure(.invalidState,message:"Quadratic reconciled target state is invalid.") }
        try equations.admitColdPhysical(physical,work:&work)
        try equations.checkColdCancellation()
        return NonlinearReconciledSubtreeRelease(admission:_NonlinearSubtreeAccelerationAdmission(release:release,physical:physical,
            descriptor:equations.descriptor,motion:motion))
    }
}

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct _NonlinearSubtreeAccelerationAdmission: Sendable {
    let release:SubtreeRelease
    let physical:KinematicState
    let descriptor:ODEDescriptor
    let motion:ConstrainedMotion
    fileprivate init(release:SubtreeRelease,physical:KinematicState,descriptor:ODEDescriptor,motion:ConstrainedMotion) {
        self.release=release;self.physical=physical;self.descriptor=descriptor;self.motion=motion
    }
}
