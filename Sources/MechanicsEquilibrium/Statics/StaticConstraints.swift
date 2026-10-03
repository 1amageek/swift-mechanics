import MechanicsConstraints
import MechanicsNumerics
public struct StaticConstraints: Sendable {
    public let system: QuadraticConstraintSystem
    public let policy: ConstraintSolvePolicy
    /// Caller cap for the assembly response path, distinct from policy.nonlinear.budget.
    public let responseBudget: NumericalBudget
    public init(system: QuadraticConstraintSystem, policy: ConstraintSolvePolicy, responseBudget: NumericalBudget) {
        self.system=system;self.policy=policy;self.responseBudget=responseBudget
    }
}
