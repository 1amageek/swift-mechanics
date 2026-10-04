
public struct EquilibriumPolicy: Sendable {
    public let limits: EquilibriumLimits
    public let nonlinear: NonlinearPolicy<Double>
    public let physicalForceTolerances: [Double]
    public let constraintTolerance: Double
    public let reactionSelection: ReactionSelection
    public let isCancelled: @Sendable () -> Bool
    public init(limits: EquilibriumLimits, nonlinear: NonlinearPolicy<Double>, physicalForceTolerances: [Double], constraintTolerance: Double,
                reactionSelection: ReactionSelection, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(EquilibriumError) {
        guard !physicalForceTolerances.isEmpty,physicalForceTolerances.count<=limits.coordinates,constraintTolerance.isFinite,constraintTolerance>=0 else { throw .invalidInput }
        for t in physicalForceTolerances { guard t.isFinite,t>=0 else { throw .invalidInput } }
        self.limits=limits; self.nonlinear=nonlinear; self.physicalForceTolerances=physicalForceTolerances
        self.constraintTolerance=constraintTolerance; self.reactionSelection=reactionSelection; self.isCancelled=isCancelled
    }
}

internal func limitedNonlinear(_ p: NonlinearPolicy<Double>, work: NumericalWork, reserved: Int) throws(EquilibriumError) -> NonlinearPolicy<Double> {
    try equilibriumNumerics { () throws(NumericalError) in
        let remain=try work.remainingBudget(reservedStorage: reserved)
        let b=try NumericalBudget(scalarStorage: min(remain.scalarStorage,p.budget.scalarStorage), arithmeticOperations: min(remain.arithmeticOperations,p.budget.arithmeticOperations), iterations: min(remain.iterations,p.budget.iterations))
        return try NonlinearPolicy(strategy: p.strategy, capability: p.capability, tolerance: p.tolerance, referenceScale: p.referenceScale, minimumDirectionNorm: p.minimumDirectionNorm,
            derivativeProbeDistance: p.derivativeProbeDistance, derivativeAbsoluteTolerance: p.derivativeAbsoluteTolerance, derivativeRelativeTolerance: p.derivativeRelativeTolerance,
            maximumFactorEntries: p.maximumFactorEntries, estimateCondition: p.estimateCondition, budget: b)
    }
}
