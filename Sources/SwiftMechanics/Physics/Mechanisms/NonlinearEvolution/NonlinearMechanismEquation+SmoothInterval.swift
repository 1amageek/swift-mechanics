@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension NonlinearMechanismEquation {
    /// Original quadratic coordinate laws have no internal trajectory knot.
    public func nextBoundary(after time:Double,through limit:Double,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> Double? { nil }
}
