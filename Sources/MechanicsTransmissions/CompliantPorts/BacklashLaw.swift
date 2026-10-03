public struct BacklashLaw: Sendable {
    public let id: UInt64
    public let revision: UInt64
    public let halfClearance: Double
    public let stiffness: Double
    public let damping: Double
    public let maximumAbsPhase: Double
    public let energyScale: Double
    public init(id: UInt64, revision: UInt64, halfClearance: Double, stiffness: Double, damping: Double, maximumAbsPhase: Double, energyScale: Double) throws(TransmissionError) {
        guard halfClearance.isFinite, halfClearance >= 0, stiffness.isFinite, stiffness > 0, damping.isFinite, damping >= 0,
              maximumAbsPhase.isFinite, maximumAbsPhase > halfClearance, energyScale.isFinite, energyScale > 0 else { throw .invalidInput }
        self.id=id; self.revision=revision; self.halfClearance=halfClearance; self.stiffness=stiffness; self.damping=damping
        self.maximumAbsPhase=maximumAbsPhase; self.energyScale=energyScale
    }
}
