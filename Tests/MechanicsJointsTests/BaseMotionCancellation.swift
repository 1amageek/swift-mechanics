import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class BaseMotionCancellation: PrescribedBaseMotionSampling, Sendable {
    private let state = Mutex(false)
    func cancelled() -> Bool { state.withLock { $0 } }
    func sampleBase(_ program: PrescribedBaseMotionProgram, time: Double, policy: PrescribedMotionPolicy,
                    work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        let original = try AnalyticPrescribedBaseMotionSampler().sampleBase(program, time: time, policy: policy, work: &work)
        state.withLock { $0 = true }
        return original
    }
}
