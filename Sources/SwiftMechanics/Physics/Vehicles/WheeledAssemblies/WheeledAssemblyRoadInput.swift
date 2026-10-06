public struct WheeledAssemblyRoadInput: Sendable {
    public let source: SourceProvenance
    public let time, validUntil: Double
    public let rear, front: BodyWrenchContribution
    public init(source: SourceProvenance, time: Double, validUntil: Double,
                rear: BodyWrenchContribution, front: BodyWrenchContribution) throws(WheeledAssemblyFailure) {
        guard source.revision > 0, time.isFinite, validUntil.isFinite, validUntil >= time else { throw .refusal(.invalidInput) }
        self.source=source; self.time=time; self.validUntil=validUntil; self.rear=rear; self.front=front
    }
}
