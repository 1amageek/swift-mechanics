public struct StationaryIslandWork: Sendable {
    public var numerical: NumericalWork
    public var loads: LoadWork
    public private(set) var compilationCalls: Int = 0
    public private(set) var failedSupplierWorkUnavailable = false
    public init(numerical: NumericalWork, loads: LoadWork) { self.numerical=numerical; self.loads=loads }
    internal mutating func beginCompilation(maximum: Int) throws(StationaryIslandFailureReason) {
        guard compilationCalls < maximum else { throw .capacityExceeded }; compilationCalls += 1
    }
    internal mutating func unavailable() { failedSupplierWorkUnavailable=true }
}
