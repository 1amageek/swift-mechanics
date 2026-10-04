public struct LoadedMechanismSleepHistory: Equatable, Sendable {
    public let mechanics:MechanismSleepHistory
    public let selection:StationaryLoadSelection
    public let previousProgramID:UInt64
    public let previousRevision:UInt64
    internal init(mechanics:MechanismSleepHistory,selection:StationaryLoadSelection,previousProgramID:UInt64,previousRevision:UInt64) {
        self.mechanics=mechanics;self.selection=selection;self.previousProgramID=previousProgramID;self.previousRevision=previousRevision
    }
}
