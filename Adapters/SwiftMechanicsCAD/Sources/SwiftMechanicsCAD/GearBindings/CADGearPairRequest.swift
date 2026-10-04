import SwiftMechanics

/// Construction explicitly declares fresh mechanics initialization from the admitted source.
public struct CADGearPairRequest: Sendable {
    public let source: CADSourceIdentity
    public let model: ModelStamp
    public let first: CADGearShaftRequest
    public let second: CADGearShaftRequest
    public let phase: Double
    public let phaseScale: Double
    public let networkID: UInt64
    public let relationID: UInt64
    public let minimumPosition: [Double]
    public let maximumPosition: [Double]
    public let minimumTime: Double
    public let maximumTime: Double
    public let fidelity: CADGearFidelity
    public init(freshSource source: CADSourceIdentity, model: ModelStamp,
                first: CADGearShaftRequest, second: CADGearShaftRequest,
                phase: Double, phaseScale: Double, networkID: UInt64, relationID: UInt64,
                minimumPosition: [Double], maximumPosition: [Double], minimumTime: Double,
                maximumTime: Double, fidelity: CADGearFidelity) throws(CADGearBindingError) {
        guard phase.isFinite, phaseScale.isFinite, phaseScale > 0,
              minimumTime.isFinite, maximumTime.isFinite, minimumTime <= maximumTime else { throw .invalidInput }
        self.source = source; self.model = model; self.first = first; self.second = second
        self.phase = phase; self.phaseScale = phaseScale; self.networkID = networkID; self.relationID = relationID
        self.minimumPosition = minimumPosition; self.maximumPosition = maximumPosition
        self.minimumTime = minimumTime; self.maximumTime = maximumTime; self.fidelity = fidelity
    }
}
