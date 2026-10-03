import MechanicsModel
public struct NodalPressureField: Sendable {
    public let frame: EntityID
    public let meshRevision: UInt64, revision: UInt64
    public let nodeIdentifiers: [UInt64], materialIdentifiers: [EntityID]
    /// Supplied current physical pressure, in pascals; not inferred from scalar contact stiffness.
    public let pressurePascals: [Double]
    public let source: SourceProvenance
    public init(frame: EntityID, meshRevision: UInt64, revision: UInt64, nodeIdentifiers: [UInt64], materialIdentifiers: [EntityID], pressurePascals: [Double], source: SourceProvenance) {
        self.frame=frame; self.meshRevision=meshRevision; self.revision=revision; self.nodeIdentifiers=nodeIdentifiers
        self.materialIdentifiers=materialIdentifiers; self.pressurePascals=pressurePascals; self.source=source
    }
}
