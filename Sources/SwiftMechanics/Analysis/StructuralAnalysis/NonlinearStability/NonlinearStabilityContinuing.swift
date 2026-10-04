public protocol NonlinearStabilityContinuing: Sendable {
    func start(_ source: NonlinearStabilitySource, position: [Double], parameter: Double,
               initialDirection: [Double], policy: NonlinearStabilityPolicy, work: inout NumericalWork)
        throws(NonlinearStabilityFailure) -> NonlinearStabilityState
    func advance(_ source: NonlinearStabilitySource, state: NonlinearStabilityState, arcStep: Double,
                 policy: NonlinearStabilityPolicy, work: inout NumericalWork)
        throws(NonlinearStabilityFailure) -> NonlinearStabilityState
    func critical(_ source: NonlinearStabilitySource, left: NonlinearStabilityState, right: NonlinearStabilityState,
                  policy: NonlinearStabilityPolicy, work: inout NumericalWork)
        throws(NonlinearStabilityFailure) -> NonlinearStabilityCriticalPoint
}
