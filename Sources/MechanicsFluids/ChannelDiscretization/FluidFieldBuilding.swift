import MechanicsNumerics
public protocol FluidFieldBuilding: Sendable {
    func makeState(channel: FluidChannel, boundary: FluidBoundary, time: Double, velocities: [Double],
                   policy: FluidPolicy, work: inout NumericalWork) throws(FluidError) -> FluidState
    func hydrostatic(channel: FluidChannel, boundary: FluidBoundary, policy: FluidPolicy,
                     work: inout NumericalWork) throws(FluidError) -> [Double]
}
