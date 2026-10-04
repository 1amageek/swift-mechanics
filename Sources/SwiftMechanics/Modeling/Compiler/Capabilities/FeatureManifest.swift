public struct FeatureManifest: Equatable, Sendable {
    public let entries: [FeatureManifestEntry]
    public let producerEvidence: [ProducerPathEvidence]

    internal init(entries: [FeatureManifestEntry], producerEvidence: [ProducerPathEvidence]) {
        self.entries = entries; self.producerEvidence = producerEvidence
    }
}
