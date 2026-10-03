import MechanicsNumerics
public protocol EquilibriumSolving: Sendable {
    func solve(_ model: StaticForceModel, constraints: StaticConstraints?, initialPosition: [Double], parameter: Double, time: Double,
               branch: EquilibriumBranch, policy: EquilibriumPolicy, work: inout NumericalWork) throws(EquilibriumError) -> EquilibriumSolution
}
