import CADIR

public struct CADAnchorReference: Sendable {
    public let source: CADSourceIdentity
    public let occurrenceID: String
    public let stableReference: StableSubshapeReference
    public let topology: TopologyReference

    /// Raw selection data grants no geometry authority; each query revalidates it.
    public init(source: CADSourceIdentity, occurrenceID: String,
                stableReference: StableSubshapeReference, topology: TopologyReference) {
        self.source = source
        self.occurrenceID = occurrenceID
        self.stableReference = stableReference
        self.topology = topology
    }
}
