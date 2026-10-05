public struct ParticleFlowIdentity: Equatable, Sendable {
    public let key: String
    public let revision: UInt64
    public let source: SourceProvenance
    public let frame: EntityID
    public let frameRevision: UInt64
    public init(key: String, revision: UInt64, source: SourceProvenance,
                frame: EntityID, frameRevision: UInt64) throws(ParticleFlowError) {
        guard !key.isEmpty, frame.kind == .frame else { throw .invalidInput }
        self.key = key; self.revision = revision; self.source = source
        self.frame = frame; self.frameRevision = frameRevision
    }
}
