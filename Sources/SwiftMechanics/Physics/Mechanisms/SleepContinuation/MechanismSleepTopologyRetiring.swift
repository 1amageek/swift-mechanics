@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public protocol MechanismSleepTopologyRetiring: Sendable {
    func prepareRetirement(source:RuntimeAcceptedState,sourceConfiguration:RuntimeConfiguration,
        checkpoints:any RuntimeCheckpointHandling,release:SubtreeRelease,retiredConstraintIDs:[UInt64],
        targetConstraints:QuadraticConstraintSystem,targetVelocityLayout:ConstraintCoordinateLayout,
        cancellation:RuntimeCancellationSource?,work:inout NumericalWork) throws(SleepTopologyFailure) -> PreparedSleepTopologyRetirement
}
