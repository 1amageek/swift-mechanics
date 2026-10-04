public struct EquilibriumBranch: Equatable, Sendable {
    public let identity: String
    public let minimumPosition: [Double]
    public let maximumPosition: [Double]
    public let maximumNormalizedStep: Double
    public init(identity: String, minimumPosition: [Double], maximumPosition: [Double], maximumNormalizedStep: Double, limits: EquilibriumLimits) throws(EquilibriumError) {
        try boundedIdentity(identity, limit: limits.identifierBytes)
        guard !minimumPosition.isEmpty, minimumPosition.count<=limits.coordinates, maximumPosition.count==minimumPosition.count,
            maximumNormalizedStep.isFinite, maximumNormalizedStep>=0 else { throw .invalidInput }
        for i in minimumPosition.indices { guard minimumPosition[i].isFinite,maximumPosition[i].isFinite,minimumPosition[i]<=maximumPosition[i] else { throw .invalidInput } }
        self.identity=identity; self.minimumPosition=minimumPosition; self.maximumPosition=maximumPosition; self.maximumNormalizedStep=maximumNormalizedStep
    }
}
