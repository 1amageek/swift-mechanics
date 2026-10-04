public struct MechanismSleepDecision: Sendable {
    public let groups:[[UInt64]]
    public let asleep:[Bool]
    public let kineticEnergy:[Double]
    internal init(groups:[[UInt64]],asleep:[Bool],kineticEnergy:[Double]) { self.groups=groups;self.asleep=asleep;self.kineticEnergy=kineticEnergy }
}
