enum ImplicitBudgetComposition {
    static func policy(_ source: NonlinearPolicy<Double>, budget: NumericalBudget) throws(NumericalError) -> NonlinearPolicy<Double> {
        try NonlinearPolicy(strategy: source.strategy, capability: source.capability, tolerance: source.tolerance,
            referenceScale: source.referenceScale, minimumDirectionNorm: source.minimumDirectionNorm,
            derivativeProbeDistance: source.derivativeProbeDistance, derivativeAbsoluteTolerance: source.derivativeAbsoluteTolerance,
            derivativeRelativeTolerance: source.derivativeRelativeTolerance, maximumFactorEntries: source.maximumFactorEntries,
            estimateCondition: source.estimateCondition, budget: budget)
    }
    static func preservingLedger(_ previous: NumericalWork, _ current: NumericalWork) -> Bool {
        current.budget == previous.budget && current.operations >= previous.operations && current.iterations >= previous.iterations &&
            current.peakScalarStorage >= previous.peakScalarStorage
    }
}
