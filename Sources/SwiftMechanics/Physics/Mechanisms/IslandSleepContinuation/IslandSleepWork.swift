public struct IslandSleepWork: Sendable {
    public var physical: StationaryIslandWork
    public var contributorEncoding: NumericalWork
    public internal(set) var supplierInvocations: Int = 0
    public internal(set) var queries: Int = 0
    public internal(set) var failedSupplierWorkUnavailable = false
    public init(physical: StationaryIslandWork, contributorEncoding: NumericalWork) { self.physical=physical;self.contributorEncoding=contributorEncoding }
}
