public struct BacklashContinuation: Sendable {
    public let networkID: UInt64
    public let rowID: UInt64
    public let layoutRevision: UInt64
    public let modelRevision: UInt64
    public let lawID: UInt64
    public let lawRevision: UInt64
    public let time: Double
    public let phase: Double
    public let storedEnergy: Double
    public let branch: BacklashBranch
    public init(networkID: UInt64,rowID: UInt64,layoutRevision: UInt64,modelRevision: UInt64,lawID: UInt64,lawRevision: UInt64,time: Double,phase: Double,storedEnergy: Double,branch: BacklashBranch) {
        self.networkID=networkID; self.rowID=rowID; self.layoutRevision=layoutRevision; self.modelRevision=modelRevision; self.lawID=lawID
        self.lawRevision=lawRevision; self.time=time; self.phase=phase; self.storedEnergy=storedEnergy; self.branch=branch
    }
}
