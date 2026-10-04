@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public protocol NonlinearSubtreeAccelerationPreparing: Sendable {
    func prepare(release:SubtreeRelease,equations:NonlinearMechanismEquation,work:inout NumericalWork) throws(RuntimeFailure) -> NonlinearReconciledSubtreeRelease
}
