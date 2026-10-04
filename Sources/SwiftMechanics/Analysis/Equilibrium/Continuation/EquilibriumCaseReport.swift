public struct EquilibriumCaseReport: Sendable {
    public let input: EquilibriumLoadCase
    public let stamp: ModelStamp
    public let modelIdentity: String
    public let branchIdentity: String
    public let suppliedSeed: [Double]
    public let status: EquilibriumCaseStatus
}
