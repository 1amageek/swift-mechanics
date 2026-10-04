public struct GranularDistributionResult: Sendable {
    public let samples: [GranularSample]
    public let random: RuntimeRandomState
    internal init(samples: [GranularSample], random: RuntimeRandomState) { self.samples=samples; self.random=random }
}
