public protocol EquilibriumContinuing: Sendable {
    func sweep(_ model:StaticForceModel,constraints:StaticConstraints?,branch:EquilibriumBranch,state:EquilibriumContinuationState,
               cases:[EquilibriumLoadCase],policy:EquilibriumPolicy,work:inout NumericalWork)throws(EquilibriumError)->EquilibriumSweepReport
}
