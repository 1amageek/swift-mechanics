public struct CoSimulationBudget: Sendable {
    public let numerical: NumericalBudget
    public let maximumActuationWork: Int
    public let maximumValidationWork: Int
    public let maximumCodecByteCapacity: Int
    public let maximumRetainedCheckpointBytes: Int
    public let maximumMacros: UInt64
    public init(numerical: NumericalBudget, maximumActuationWork: Int, maximumValidationWork: Int,
                maximumCodecByteCapacity: Int, maximumRetainedCheckpointBytes: Int,
                maximumMacros: UInt64) throws(CoSimulationFailure) {
        guard maximumActuationWork >= 0, maximumValidationWork >= 0, maximumCodecByteCapacity >= 0,
              maximumRetainedCheckpointBytes >= 0, maximumMacros > 0 else { throw .refusal(.invalidInput) }
        self.numerical=numerical; self.maximumActuationWork=maximumActuationWork
        self.maximumValidationWork=maximumValidationWork; self.maximumCodecByteCapacity=maximumCodecByteCapacity
        self.maximumRetainedCheckpointBytes=maximumRetainedCheckpointBytes; self.maximumMacros=maximumMacros
    }
}
