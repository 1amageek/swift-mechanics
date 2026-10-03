import MechanicsCompiler
import MechanicsDynamics
import MechanicsNumerics
public protocol EquilibriumLinearizing: Sendable {
    func linearize(_ point: EquilibriumSolution, compiled: CompiledMechanicalModel, dynamics: RigidDynamicsSystem, reduction: EquilibriumReduction,
                   policy: EquilibriumLinearizationPolicy, work: inout NumericalWork) throws(EquilibriumError) -> EquilibriumLinearization
}
