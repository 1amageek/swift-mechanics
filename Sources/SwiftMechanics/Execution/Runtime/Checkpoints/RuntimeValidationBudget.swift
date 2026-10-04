public struct RuntimeValidationBudget: Equatable, Sendable {
    public let workUnits: Int
    public let scratchBytes: Int
    public init(workUnits: Int, scratchBytes: Int) throws(RuntimeFailure) {
        guard workUnits >= 0, scratchBytes >= 0 else { throw RuntimeFailure(.invalidInput, message: "Validation budget must be nonnegative.") }
        self.workUnits = workUnits; self.scratchBytes = scratchBytes
    }
}
