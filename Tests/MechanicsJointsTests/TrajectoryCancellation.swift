import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class TrajectoryCancellation: PrescribedTrajectorySampling, PrescribedBaseTrajectorySampling, PrescribedTrajectoryBoundaryQuerying, Sendable {
    private let state = Mutex(false)
    func cancelled() -> Bool { state.withLock { $0 } }
    private func completed() { state.withLock { $0 = true } }
    func sample(_ program: PrescribedTrajectoryProgram,time: Double,policy: PrescribedTrajectoryPolicy,
                work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample {
        let result = try AnalyticPrescribedTrajectorySampler().sample(program,time: time,policy: policy,work: &work)
        completed();return result
    }
    func sampleBase(_ program: PrescribedBaseTrajectoryProgram,time: Double,policy: PrescribedTrajectoryPolicy,
                    work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        let result = try AnalyticPrescribedBaseTrajectorySampler().sampleBase(program,time: time,policy: policy,work: &work)
        completed();return result
    }
    func nextBoundary(_ program: PrescribedTrajectoryProgram,after time: Double,through limit: Double,
                      policy: PrescribedTrajectoryPolicy,work: inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        let result = try PrescribedTrajectoryBoundaryQuery().nextBoundary(program,after: time,through: limit,policy: policy,work: &work)
        completed();return result
    }
    func nextBaseBoundary(_ program: PrescribedBaseTrajectoryProgram,after time: Double,through limit: Double,
                          policy: PrescribedTrajectoryPolicy,work: inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        let result = try PrescribedTrajectoryBoundaryQuery().nextBaseBoundary(program,after: time,through: limit,policy: policy,work: &work)
        completed();return result
    }
}
