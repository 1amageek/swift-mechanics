public protocol FluidEvolving: Sendable {
    func steady(state: FluidState, boundary: FluidBoundary, policy: FluidPolicy,
                work: inout NumericalWork) throws(FluidError) -> FluidEvolution
    func step(state: FluidState, boundary: FluidBoundary, duration: Double, policy: FluidPolicy,
              work: inout NumericalWork) throws(FluidError) -> FluidEvolution
}
