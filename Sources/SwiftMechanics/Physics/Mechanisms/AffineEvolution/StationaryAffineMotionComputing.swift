@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol StationaryAffineMotionComputing: Sendable {
    func loadedMotion(physical:KinematicState,selection:StationaryLoadSelection,execution:any StationaryLoadExecuting,work:inout NumericalWork) throws(RuntimeFailure) -> StationaryAffineMotion
    func loadedMotion(physical:KinematicState,selection:StationaryLoadSelection,drive:[Double],execution:any StationaryLoadExecuting,work:inout NumericalWork) throws(RuntimeFailure) -> StationaryAffineMotion
}
