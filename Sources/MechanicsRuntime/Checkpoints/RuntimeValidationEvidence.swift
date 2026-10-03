public struct RuntimeValidationEvidence: Equatable, Sendable {
    public let workUnitsUsed: Int
    public let scratchBytesUsed: Int
    public init(workUnitsUsed: Int, scratchBytesUsed: Int) throws(RuntimeFailure) {
        guard workUnitsUsed >= 0, scratchBytesUsed >= 0 else { throw RuntimeFailure(.invalidInput, message: "Validation evidence counters must be nonnegative.") }
        self.workUnitsUsed = workUnitsUsed; self.scratchBytesUsed = scratchBytesUsed
    }
}
