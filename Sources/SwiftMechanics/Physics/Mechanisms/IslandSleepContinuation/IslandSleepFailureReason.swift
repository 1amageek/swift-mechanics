public enum IslandSleepFailureReason: Error, Sendable {
    indirect case runtime(RuntimeFailure)
    indirect case integration(IntegrationFailure)
    indirect case physical(StationaryIslandFailure)
    indirect case numerical(NumericalError)
    indirect case load(LoadError)
    indirect case supplierLedgerFailure(IslandSleepFailureReason?)
}
