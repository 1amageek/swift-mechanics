import MechanicsNumerics
import MechanicsFluids
struct SteadyOnlyFluidEvolution: FluidEvolving, Sendable {
    func steady(state:FluidState,boundary:FluidBoundary,policy:FluidPolicy,work:inout NumericalWork) throws(FluidError)->FluidEvolution {
        try FluidFixtures.solver().steady(state:state,boundary:boundary,policy:policy,work:&work)
    }
    func step(state:FluidState,boundary:FluidBoundary,duration:Double,policy:FluidPolicy,work:inout NumericalWork) throws(FluidError)->FluidEvolution {
        // Actual steady field is deliberately returned in a transient path; lifecycle authority must reject it.
        try FluidFixtures.solver().steady(state:state,boundary:boundary,policy:policy,work:&work)
    }
}
