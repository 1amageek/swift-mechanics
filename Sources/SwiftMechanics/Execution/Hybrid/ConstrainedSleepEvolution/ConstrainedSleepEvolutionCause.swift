public indirect enum ConstrainedSleepEvolutionCause: Error, Sendable {
    case hybrid(HybridError)
    case runtime(RuntimeFailure)
    case sleep(IslandSleepFailure)
    case impact(ConstrainedImpactError)
    case load(LoadError)
    case supplierLedgerFailure(ConstrainedSleepEvolutionCause?)
}
