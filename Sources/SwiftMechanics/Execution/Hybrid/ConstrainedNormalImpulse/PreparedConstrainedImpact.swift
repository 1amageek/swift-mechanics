public final class PreparedConstrainedImpact: Sendable {
    public let source: HardImpactInput
    public let impact: PreparedImpact
    public let constraints: QuadraticConstraintSystem
    public let policy: ConstrainedImpactPolicy
    public let retainedRowIDs: [UInt64]
    /// Row-major physical rows B mapping SI generalized velocity to 1/s.
    public let retainedRows: [Double]
    internal init(source: HardImpactInput, impact: PreparedImpact, constraints: QuadraticConstraintSystem,
                  policy: ConstrainedImpactPolicy, rowIDs: [UInt64], rows: [Double]) {
        self.source = source; self.impact = impact; self.constraints = constraints; self.policy = policy
        retainedRowIDs = rowIDs; retainedRows = rows
    }
}
